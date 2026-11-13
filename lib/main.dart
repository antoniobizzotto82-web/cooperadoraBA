import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

const navy = Color(0xFF082B49);
const gold = Color(0xFFC99B43);
const schoolName = 'Escuela N.º 2 Nicolás Antonio';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.database;
  runApp(const CooperadoraApp());
}

class CooperadoraApp extends StatelessWidget {
  const CooperadoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cooperadora Escuela 2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: gold),
        scaffoldBackgroundColor: const Color(0xFFF5F1E8),
        appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const GatePage(),
    );
  }
}

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'cooperadora_escuela2.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile(
            id INTEGER PRIMARY KEY CHECK(id=1),
            fullName TEXT NOT NULL, phone TEXT NOT NULL, role TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tutors(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, student TEXT NOT NULL, phone TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            receiptNo INTEGER NOT NULL UNIQUE,
            tutorId INTEGER NOT NULL,
            amount REAL NOT NULL,
            method TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY(tutorId) REFERENCES tutors(id)
          )
        ''');
      },
    );
    await _db!.execute('PRAGMA foreign_keys = ON');
    return _db!;
  }

  Future?> profile() async {
    final rows = await (await database).query('profile', where: 'id=1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveProfile(String name, String phone, String role) async {
    await (await database).insert('profile',
      {'id':  1, 'fullName': name, 'phone': phone, 'role': role},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List>> tutors() async =>
      (await database).query('tutors', orderBy: 'name COLLATE NOCASE');

  Future<int> addTutor(String name, String student, String phone) async =>
      (await database).insert('tutors', {
        'name': name, 'student': student, 'phone': phone,
        'createdAt': DateTime.now().toIso8601String(),
      });

  Future<List>> payments() async =>
      (await database).rawQuery('''
        SELECT payments.*, tutors.name AS tutorName, tutors.phone AS tutorPhone,
        tutors.student AS studentName
        FROM payments JOIN tutors ON tutors.id=payments.tutorId
        ORDER BY payments.receiptNo DESC
      ''');

  Future<int> addPayment(int tutorId, double amount, String method, String note) async {
    final db = await database;
    return db.transaction((txn) async {
      final next = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COALESCE(MAX(receiptNo),0)+1 FROM payments')) ?? 1;
      return txn.insert('payments', {
        'receiptNo': next,
        'tutorId': tutorId,
        'amount': amount,
        'method': method,
        'date': DateTime.now().toIso8601String(),
        'note': note,
      });
    });
  }

  Future> totals() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
      COALESCE(SUM(amount),0) AS total,
      COALESCE(SUM(CASE WHEN method='Transferencia' THEN amount ELSE 0 END),0) AS transfer,
      COALESCE(SUM(CASE WHEN method='Efectivo' THEN amount ELSE 0 END),0) AS cash,
      COUNT(*) AS count
      FROM payments
    ''');
    return rows.first;
  }

  Future> exportAll() async {
    final db = await database;
    final profileRows = await db.query('profile');
    final tutorRows = await db.query('tutors', orderBy: 'id');
    final paymentRows = await db.query('payments', orderBy: 'receiptNo');
    return {
      'app': 'Cooperadora Escuela 2',
      'school': schoolName,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profileRows,
      'tutors': tutorRows,
      'payments': paymentRows,
    };
  }
}

String money(num value) => NumberFormat.currency(locale: 'es_AR', symbol: r'$ ', decimalDigits: 2).format(value);
String phoneDigits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

class GatePage extends StatefulWidget {
  const GatePage({super.key});
  @override
  State<GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<GatePage> {
  @override
  void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final profile = await AppDb.instance.profile();
    if (!mounted) return;
    if (profile == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupPage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final role = TextEditingController();
  bool saving = false;

  Future<void> save() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty || role.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completá nombre, celular y cargo.')));
      return;
    }
    setState(() => saving = true);
    await AppDb.instance.saveProfile(name.text.trim(), phoneDigits(phone.text), role.text.trim());
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [navy, Color(0xFF174A70)])),
      child: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(
          children: [
            Image.asset('assets/images/fondo_cooperadora.jpg', height: 150, fit: BoxFit.contain),
            const SizedBox(height: 12),
            const Text('Bienvenido/a', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: navy)),
            const Text('Configuración del titular de la aplicación'),
            const SizedBox(height: 20),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre y apellido completo')),
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Celular con código de área y país', hintText: 'Ej. 549266...')),
            const SizedBox(height: 12),
            TextField(controller: role, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Cargo en la Cooperadora')),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: const Text('Guardar y comenzar')),
            const SizedBox(height: 8),
            const Text('El número ingresado se usará como referencia del responsable. WhatsApp abrirá los chats para confirmar cada envío.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ))),
      ))),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  int refreshKey = 0;
  Future<void> refresh() async { setState(() => refreshKey++); }
  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(key: ValueKey('d$refreshKey'), onChanged: refresh),
      TutorsPage(key: ValueKey('t$refreshKey'), onChanged: refresh),
      PaymentsPage(key: ValueKey('p$refreshKey'), onChanged: refresh),
      HistoryPage(key: ValueKey('h$refreshKey')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperadora · Escuela N.º 2'),
        actions: [IconButton(tooltip: 'Exportar respaldo', onPressed: exportBackup, icon: const Icon(Icons.backup))],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Tutores'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Cobrar'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Historial'),
        ],
      ),
    );
  }

  Future<void> exportBackup() async {
    try {
      final data = await AppDb.instance.exportAll();
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File(p.join(dir.path, 'respaldo_cooperadora_$stamp.json'));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles([XFile(file.path)], text: 'Respaldo de la Cooperadora - $schoolName');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
    }
  }
}

class Dashboard extends StatelessWidget {
  final VoidCallback onChanged;
  const Dashboard({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: Future.wait([AppDb.instance.totals(), AppDb.instance.tutors(), AppDb.instance.profile()]),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final totals = snapshot.data![0] as Map<String, dynamic>;
      final tutors = snapshot.data![1] as List>;
      final profile = snapshot.data![2] as Map<String, Object?>?;
      return ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(alignment: Alignment.bottomLeft, children: [
          Image.asset('assets/images/fondo_cooperadora.jpg', height: 175, width: double.infinity, fit: BoxFit.cover),
          Container(height: 175, decoration: BoxDecoration(gradient: LinearGradient(colors: [navy.withValues(alpha: 0.85), Colors.transparent], begin: Alignment.bottomLeft, end: Alignment.topRight))),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COMISIÓN COOPERADORA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(schoolName, style: const TextStyle(color: Colors.white, fontSize: 15)),
            if (profile != null) Text('${profile['fullName']} · ${profile['role']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ])),
        const SizedBox(height: 16),
        _stat('Total recaudado', money((totals['total'] as num)), Icons.account_balance_wallet, navy),
        Row(children: [
          Expanded(child: _stat('Transferencias', money(totals['transfer'] as num), Icons.account_balance, Colors.blue.shade800)),
          const SizedBox(width: 10),
          Expanded(child: _stat('Efectivo', money(totals['cash'] as num), Icons.payments, Colors.green.shade800)),
        ]),
        Row(children: [
          Expanded(child: _stat('Pagos registrados', '${totals['count']}', Icons.receipt, navy)),
          const SizedBox(width: 10),
          Expanded(child: _stat('Tutores registrados', '${tutors.length}', Icons.people, navy)),
        ]),
        const SizedBox(height: 10),
        const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Los datos se guardan en este teléfono. Exportá un respaldo con el ícono de la nube antes de cambiar o reiniciar el dispositivo.'))),
      ]);
    },
  );
}

Widget _stat(String title, String value, IconData icon, Color color) =>
  Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: color), const SizedBox(height: 8),
    Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
  ])));

class TutorsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const TutorsPage({super.key, required this.onChanged});
  @override
  State<TutorsPage> createState() => _TutorsPageState();
}
class _TutorsPageState extends State<TutorsPage> {
  Future<void> add() async {
    final name = TextEditingController(), student = TextEditingController(), phone = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Nuevo tutor/a'),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre y apellido del tutor')),
        const SizedBox(height: 10),
        TextField(controller: student, decoration: const InputDecoration(labelText: 'Alumno/a')),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp (con código de país)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))],
    ));
    if (ok == true && name.text.trim().isNotEmpty && phoneDigits(phone.text).isNotEmpty) {
      await AppDb.instance.addTutor(name.text.trim(), student.text.trim(), phoneDigits(phone.text));
      widget.onChanged();
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.person_add), label: const Text('Agregar tutor')),
    body: FutureBuilder(future: AppDb.instance.tutors(), builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data!;
      if (rows.isEmpty) return const Center(child: Text('Todavía no hay tutores registrados.'));
      return ListView.builder(padding: const EdgeInsets.only(bottom: 90), itemCount: rows.length, itemBuilder: (context, i) {
        final t = rows[i];
        return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(
          leading: const CircleAvatar(backgroundColor: navy, child: Icon(Icons.person, color: Colors.white)),
          title: Text('${t['name']}'),
          subtitle: Text('Alumno/a: ${t['student']}\nWhatsApp: ${t['phone']}'),
          isThreeLine: true,
        ));
      });
    }),
  );
}

class PaymentsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const PaymentsPage({super.key, required this.onChanged});
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}
class _PaymentsPageState extends State<PaymentsPage> {
  int? tutorId;
  String method = 'Transferencia';
  final amount = TextEditingController(), note = TextEditingController();
  bool busy = false;

  Future<void> register() async {
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (tutorId == null || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elegí un tutor e ingresá un importe válido.')));
      return;
    }
    setState(() => busy = true);
    await AppDb.instance.addPayment(tutorId!, value, method, note.text.trim());
    setState(() { busy = false; amount.clear(); note.clear(); });
    widget.onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado y comprobante numerado.')));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: AppDb.instance.tutors(),
    builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final tutors = snap.data!;
      if (tutors.isEmpty) return const Center(child: Text('Primero registrá al menos un tutor en la pestaña Tutores.'));
      tutorId ??= tutors.first['id'] as int;
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Registrar colaboración', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: tutorId,
          decoration: const InputDecoration(labelText: 'Tutor/a'),
          items: tutors.map((t) => DropdownMenuItem(value: t['id'] as int, child: Text('${t['name']}'))).toList(),
          onChanged: (v) => setState(() => tutorId = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importe', prefixText: r'$ ')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: method,
          decoration: const InputDecoration(labelText: 'Medio de pago'),
          items: const [DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')), DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo'))],
          onChanged: (v) => setState(() => method = v ?? 'Transferencia'),
        ),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Observación (opcional)')),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: busy ? null : register, icon: const Icon(Icons.check_circle), label: const Text('Registrar pago')),
        const SizedBox(height: 10),
        const Text('Al guardar se asigna el próximo número correlativo de comprobante. Luego podés compartir el comprobante desde Historial.', style: TextStyle(color: Colors.black54)),
      ]);
    },
  );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: AppDb.instance.payments(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final payments = snapshot.data as List>;
          if (payments.isEmpty) {
            return const Center(child: Text('No hay pagos registrados todavía.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: payments.length,
            itemBuilder: (context, i) {
              const paymentKey = Key('payment_item'); // Opcional o const si aplica
              final p = payments[i];
              final dateStr = p['date'] != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(p['date'] as String)) 
                  : '';
              return Card(
                key: paymentKey,
                child: ListTile(
                  title: Text('Comprobante N.º ${p['receiptNo']} - ${money(p['amount'] as num)}'),
                  subtitle: Text('Tutor/a: ${p['tutorName']}\nAlumno/a: ${p['studentName']}\nFecha: $dateStr\nMétodo: ${p['method']}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.share, color: navy),
                    onPressed: () => _shareReceipt(p),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _shareReceipt(Map<String, Object?> p) async {
    final text = 'Comprobante N.º ${p['receiptNo']}\n'
        'Escuela: $schoolName\n'
        'Tutor/a: ${p['tutorName']}\n'
        'Alumno/a: ${p['studentName']}\n'
        'Importe: ${money(p['amount'] as num)}\n'
        'Medio: ${p['method']}\n'
        'Fecha: ${p['date']}';
    
    final phone = phoneDigits('${p['tutorPhone']}');
    if (phone.isNotEmpty) {
      final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }
    await Share.share(text);
  }
}
