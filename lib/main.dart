import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Deteksi Web
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 0. GLOBAL STATE & MODELS
// ==========================================
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Simulasi Penyimpanan Lokal untuk Riwayat Login (Session Based)
List<Map<String, String>> _localLoginHistory = [];

class VulnerabilityReport {
  String id;
  String title;
  String severity;
  String description;
  DateTime timestamp;
  String status;
  String reporterName;
  String reporterId;

  VulnerabilityReport({
    required this.id,
    required this.title,
    required this.severity,
    required this.description,
    required this.timestamp,
    required this.status,
    required this.reporterName,
    required this.reporterId,
  });

  factory VulnerabilityReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return VulnerabilityReport(
      id: doc.id,
      title: data['title'] ?? '',
      severity: data['severity'] ?? 'Low',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'Open',
      reporterName: data['reporterName'] ?? 'Anonim',
      reporterId: data['reporterId'] ?? '',
    );
  }
}

// ==========================================
// 1. MAIN ENTRY POINT
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi Firebase Anda
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyALG166hFi_3paJ03htBs9-jxlHEq_knNk",
      appId: "1:604190695271:web:ce477bd157bde3d3d399c2",
      messagingSenderId: "604190695271",
      projectId: "helpdeskit-a851f",
      storageBucket: "helpdeskit-a851f.firebasestorage.app",
      authDomain: "helpdeskit-a851f.firebaseapp.com",
    ),
  );

  runApp(const ProjectFApp());
}

class ProjectFApp extends StatelessWidget {
  const ProjectFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Helpdesk IT / Ticket Keluhan Kampus', // UBAH JUDUL APP
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // TEMA TERANG (LIGHT)
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E3A8A), // Blue 900
              primary: const Color(0xFF1E3A8A),
              secondary: const Color(0xFF3B82F6),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
            fontFamily: 'Roboto',
            cardTheme: const CardThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)))),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF1E3A8A)),
              titleTextStyle: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5)),
            ),
          ),
          // TEMA GELAP (DARK)
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6),
              brightness: Brightness.dark,
              primary: const Color(0xFF3B82F6),
              surface: const Color(0xFF1E293B),
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF1E293B),
              surfaceTintColor: Color(0xFF1E293B),
              elevation: 4,
              shadowColor: Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF334155),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            iconTheme: const IconThemeData(color: Colors.white70),
          ),
          home: const LoginPage(),
        );
      },
    );
  }
}

// ==========================================
// 2. HALAMAN LOGIN
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _techEmailController = TextEditingController();
  final _techPassController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _usernameController = TextEditingController(); 

  bool _isLoading = false;
  bool _isObscure = true;
  bool _isTeknisiMode = false; 
  String _verificationId = "";
  bool _isDemoMode = false;

  // --- VALIDATOR NOMOR TELEPON ---
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nomor telepon wajib diisi';
    }
    String cleanPhone = value.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanPhone)) {
      return 'Hanya boleh angka';
    }
    if (cleanPhone.length < 10 || cleanPhone.length > 13) {
      return 'Nomor HP harus 10-13 digit';
    }
    return null;
  }

  Future<void> _handlePhoneLogin() async {
    if (_usernameController.text.isEmpty) {
      _showMessage("Mohon isi Nama Anda.", isError: true);
      return;
    }
    
    String? phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError, isError: true);
      return;
    }

    setState(() { _isLoading = true; _isDemoMode = false; });

    String phone = _phoneController.text.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (phone.startsWith('0')) phone = "+62${phone.substring(1)}";
    else if (phone.startsWith('62')) phone = "+$phone";

    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(seconds: 1)); 
        _activateDemoMode(reason: "SMS Web butuh ReCAPTCHA");
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            await _signInWithCredential(credential);
          },
          verificationFailed: (FirebaseAuthException e) {
            _activateDemoMode(reason: "Limit/Billing Firebase");
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() { _verificationId = verificationId; _isLoading = false; });
            _showMessage("Kode OTP terkirim ke SMS/WA!");
            _showOtpDialog();
          },
          codeAutoRetrievalTimeout: (String verificationId) { _verificationId = verificationId; },
        );
      }
    } catch (e) {
      _activateDemoMode(reason: "Error Jaringan/Server");
    }
  }

  // --- LOGIN GOOGLE (WEB/POPUP) ---
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      authProvider.setCustomParameters({'prompt': 'select_account'});
      
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
      if (userCredential.user != null) {
        _addToLocalHistory(userCredential.user!.displayName ?? "User Google", "Google Account");
        await _saveUserToFirestore(userCredential);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Google Login Error: $e"); 
      _showMessage("Gagal Login. Cek koneksi atau konfigurasi SHA-1.", isError: true);
    }
  }

  void _activateDemoMode({String reason = ""}) {
    setState(() { _isDemoMode = true; _isLoading = false; });
    if (reason.isNotEmpty) {
      _showMessage("Info: Menggunakan Mode Simulasi ($reason)");
    }
    _showOtpDialog();
  }

  void _showOtpDialog() {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_isDemoMode ? "Mode Simulasi" : "Masukkan OTP"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isDemoMode 
              ? "Gunakan kode: 123456" 
              : "Masukkan 6 digit kode yang dikirim ke nomor Anda."),
            if (_isDemoMode)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text("Info: Mode ini menggunakan Akun Demo Tetap agar data tersimpan.", 
                  style: TextStyle(color: Colors.blue, fontSize: 12)),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              autofocus: true, 
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              textInputAction: TextInputAction.done, 
              onSubmitted: (_) { 
                Navigator.pop(context); 
                _verifyOtpInput(); 
              },
              style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(counterText: "", border: UnderlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); setState(() => _isLoading = false); }, child: const Text("Batal")),
          FilledButton(onPressed: () { Navigator.pop(context); _verifyOtpInput(); }, child: const Text("Verifikasi")),
        ],
      ),
    );
  }

  Future<void> _verifyOtpInput() async {
    setState(() => _isLoading = true);
    String smsCode = _otpController.text.trim();

    try {
      UserCredential userCredential;
      if (_isDemoMode) {
        if (smsCode == "123456") {
          try {
            userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: "demo_user@projectf.com", 
              password: "demouser123"
            );
          } catch (e) {
            userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: "demo_user@projectf.com", 
              password: "demouser123"
            );
          }
        } else {
          throw FirebaseAuthException(code: 'invalid-otp', message: "Kode Salah");
        }
      } else {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: smsCode);
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }
      
      _addToLocalHistory(_usernameController.text, _phoneController.text);
      await _saveUserToFirestore(userCredential);
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Verifikasi Gagal: ${e.toString()}", isError: true);
    }
  }

  void _addToLocalHistory(String name, String contact) {
    final existing = _localLoginHistory.where((e) => e['contact'] == contact);
    if (existing.isEmpty) {
      _localLoginHistory.add({'name': name, 'contact': contact});
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential uc = await FirebaseAuth.instance.signInWithCredential(credential);
      await _saveUserToFirestore(uc);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- PERBAIKAN LOGIKA PENYIMPANAN USER ---
  Future<void> _saveUserToFirestore(UserCredential userCredential) async {
    final user = userCredential.user;
    if (user == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    String displayName = _usernameController.text.isEmpty ? (user.displayName ?? "User") : _usernameController.text;
    String phoneNumber = _isDemoMode ? _phoneController.text : (user.phoneNumber ?? _phoneController.text);
    String role = 'User'; // Default role

    try {
      // 1. Cek dulu apakah user sudah ada di database
      final docSnapshot = await userDocRef.get();
      
      if (docSnapshot.exists) {
        // Jika ada, ambil role yang sudah tersimpan (misal: 'Teknisi')
        role = docSnapshot.get('role') ?? 'User';
        // Jika username di input kosong, pakai yang lama
        if (_usernameController.text.isEmpty) {
          displayName = docSnapshot.get('name') ?? displayName;
        }
      }

      // 2. Simpan/Update data (Pastikan role yang dipakai adalah hasil pengecekan di atas)
      await userDocRef.set({
        'name': displayName,
        'phone': phoneNumber,
        'email': user.email,
        'role': role, // <--- PENTING: Gunakan role dari DB jika ada, jangan di-overwrite jadi 'User'
        'lastLogin': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        // 3. Arahkan ke dashboard sesuai role yang didapat
        _navigateToDashboard(role: role, name: displayName, userId: user.uid);
      }
    } catch (e) {
      print("Error saving user: $e");
      // Fallback jika error koneksi
      if (mounted) {
        _navigateToDashboard(role: role, name: displayName, userId: user.uid);
      }
    }
  }

  Future<void> _handleTeknisiLogin() async {
    if (_techEmailController.text.isEmpty || _techPassController.text.isEmpty) {
      _showMessage("Isi Email dan Password!", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    String email = _techEmailController.text.trim();
    if (!email.contains('@')) email += "@projectf.com";

    try {
      UserCredential uc = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: _techPassController.text);
      
      // Ambil role teknisi dari database juga untuk memastikan validitas
      final doc = await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).get();
      String name = "Teknisi";
      if(doc.exists) {
        name = doc.get('name') ?? "Teknisi";
      }

      if (mounted) {
        _navigateToDashboard(role: "Teknisi", name: name, userId: uc.user!.uid);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Login Gagal. Cek kredensial.", isError: true);
    }
  }

  void _navigateToDashboard({required String role, required String name, required String userId}) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainGate(userRole: role, userName: name, userId: userId)));
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (ctx, mode, _) {
                return IconButton(
                  style: IconButton.styleFrom(backgroundColor: Theme.of(context).cardTheme.color),
                  icon: Icon(mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode_rounded),
                  onPressed: () {
                    themeNotifier.value = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, size: 120, color: Colors.blueAccent),
                    const SizedBox(height: 30),
                    // UBAH TULISAN DI SINI (DESKTOP VIEW)
                    const Text(
                      "Helpdesk IT / Ticket Keluhan Kampus", 
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32, // Ukuran font disesuaikan agar muat
                        fontWeight: FontWeight.bold, 
                        color: Colors.white, 
                        letterSpacing: 2
                      )
                    ),
                    const SizedBox(height: 10),
                    Text("Secure Vulnerability Management", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18)),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 1,
            child: Container(
              color: bgColor, 
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                          child: Row(
                            children: [
                              Expanded(child: _buildToggleBtn("User", !_isTeknisiMode)),
                              Expanded(child: _buildToggleBtn("Teknisi", _isTeknisiMode)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(_isTeknisiMode ? "Login Teknisi" : "Login User", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        Text(_isTeknisiMode ? "Masuk ke panel admin" : "Verifikasi nomor HP untuk lanjut", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                        const SizedBox(height: 30),
                        
                        if (!_isTeknisiMode) ...[
                          if (_localLoginHistory.isNotEmpty) ...[
                            Text("Login Cepat (Riwayat)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _localLoginHistory.map((h) => InkWell(
                                onTap: () {
                                  if (h['contact'] == 'Google Account') {
                                    _handleGoogleLogin();
                                  } else {
                                    setState(() {
                                      _usernameController.text = h['name']!;
                                      _phoneController.text = h['contact']!;
                                    });
                                  }
                                },
                                child: Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    child: Icon(h['contact'] == 'Google Account' ? Icons.g_mobiledata : Icons.person, size: 16, color: Theme.of(context).primaryColor),
                                  ),
                                  label: Text(h['name']!),
                                  backgroundColor: Theme.of(context).cardTheme.color,
                                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          TextField(
                            controller: _usernameController, 
                            textInputAction: TextInputAction.next, 
                            autofillHints: const [AutofillHints.name], 
                            decoration: const InputDecoration(labelText: "Nama Lengkap", prefixIcon: Icon(Icons.person_outline)),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _phoneController, 
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done, 
                            autofillHints: const [AutofillHints.telephoneNumber], 
                            onSubmitted: (_) => _handlePhoneLogin(), 
                            decoration: const InputDecoration(labelText: "Nomor WhatsApp / HP", prefixIcon: Icon(Icons.phone_android_rounded), hintText: "08xxxxxxxxxx (10-12 digit)"),
                          ),
                          const SizedBox(height: 25),
                          SizedBox(height: 50, child: FilledButton(onPressed: _isLoading ? null : _handlePhoneLogin, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Masuk"))),
                          
                          const SizedBox(height: 20),
                          Row(children: [Expanded(child: Divider(color: Colors.grey[300])), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("ATAU", style: TextStyle(color: Colors.grey[500], fontSize: 12))), Expanded(child: Divider(color: Colors.grey[300]))]),
                          const SizedBox(height: 20),
                          
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleLogin,
                              icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                              label: const Text("Masuk dengan Google"),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          )

                        ] else ...[
                          TextField(
                            controller: _techEmailController, 
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(labelText: "ID Teknisi", prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _techPassController, 
                            obscureText: _isObscure, 
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _handleTeknisiLogin(), 
                            decoration: InputDecoration(labelText: "Password", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isObscure = !_isObscure))),
                          ),
                          const SizedBox(height: 25),
                          SizedBox(height: 50, child: FilledButton(onPressed: _isLoading ? null : _handleTeknisiLogin, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Masuk"))),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String title, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isTeknisiMode = title == "Teknisi"),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isActive ? Theme.of(context).primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(25)),
        child: Center(child: Text(title, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

// ==========================================
// 3. MAIN GATE & SHARED DASHBOARD WIDGETS
// ==========================================
class MainGate extends StatelessWidget {
  final String userRole;
  final String userName;
  final String userId;
  const MainGate({super.key, required this.userRole, required this.userName, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Navigasi berdasarkan role yang diterima
    return userRole == 'Teknisi' ? TeknisiDashboard(userName: userName, userId: userId) : UserDashboard(userName: userName, userId: userId);
  }
}

// Fungsi Shared untuk Dialog Laporan
void showReportDialog(BuildContext context, String userName, String userId, {VoidCallback? onSuccess}) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String selectedSeverity = 'Low'; // Default Severity

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Buat Laporan Baru"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Judul Masalah", hintText: "Cth: Bug Login")),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedSeverity,
              items: ['Low', 'Medium', 'High', 'Critical'].map((String level) {
                Color color;
                switch (level) {
                  case 'Critical': color = Colors.red; break;
                  case 'High': color = Colors.orange[800]!; break;
                  case 'Medium': color = Colors.orange; break;
                  default: color = Colors.green;
                }
                return DropdownMenuItem(
                  value: level,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: color, size: 20),
                      const SizedBox(width: 10),
                      Text(level, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedSeverity = val!),
              decoration: const InputDecoration(labelText: "Tingkat Kesulitan", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: "Deskripsi", hintText: "Jelaskan detailnya...")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.isNotEmpty) {
                // PENYIMPANAN KE FIRESTORE (PERSISTENT)
                await FirebaseFirestore.instance.collection('vulnerabilities').add({
                  'title': titleCtrl.text,
                  'description': descCtrl.text,
                  'severity': selectedSeverity,
                  'status': 'Open',
                  'timestamp': Timestamp.now(),
                  'reporterName': userName,
                  'reporterId': userId, // PENTING: ID ini mengikat laporan ke user
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessDialog(context);
                  if (onSuccess != null) onSuccess();
                }
              }
            },
            child: const Text("Kirim Laporan"),
          )
        ],
      ),
    ),
  );
}

void _showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
      title: const Text("Berhasil!"),
      content: const Text("Laporan Anda telah terkirim dan akan segera ditinjau oleh tim teknisi.", textAlign: TextAlign.center),
      actions: [
        Center(child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text("OK, Mengerti")))
      ],
    ),
  );
}

// ==========================================
// 4. UI USER (RE-DESIGNED)
// ==========================================
class UserDashboard extends StatefulWidget {
  final String userName;
  final String userId;
  const UserDashboard({super.key, required this.userName, required this.userId});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Dashboard"), centerTitle: false),
      body: _index == 0 ? _buildHome() : _buildSettings(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: "Beranda"),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: "Pengaturan"),
        ],
      ),
      floatingActionButton: _index == 0 ? FloatingActionButton.extended(
        onPressed: () => showReportDialog(context, widget.userName, widget.userId),
        label: const Text("Lapor"),
        icon: const Icon(Icons.add_comment_rounded),
      ) : null,
    );
  }

  Widget _buildHome() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          // STREAM BUILDER: Mengambil data LIVE dari Firestore berdasarkan ID User
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vulnerabilities')
                .where('reporterId', isEqualTo: widget.userId) // Filter hanya milik user ini
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Belum ada riwayat laporan.", style: TextStyle(color: Colors.grey)));
              }

              // Konversi ke model dan urutkan
              final docs = snapshot.data!.docs.map((d) => VulnerabilityReport.fromFirestore(d)).toList();
              docs.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Urutkan terbaru

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (ctx, i) => _buildTicketCard(
                  docs[i], 
                  onEdit: () => _editReportUser(docs[i]),
                  // User masih boleh menghapus laporan sendiri
                  onDelete: () => _deleteReportUser(docs[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Selamat Datang,", style: TextStyle(color: Colors.grey[500])),
          Text(widget.userName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Pantau status laporan keamanan Anda di sini.", style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  void _editReportUser(VulnerabilityReport item) {
    if (item.status != 'Open') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan yang sedang diproses tidak bisa diedit.")));
      return;
    }
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl = TextEditingController(text: item.description);
    String severity = item.severity;

    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text("Edit Laporan"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Judul")),
        const SizedBox(height: 15),
        DropdownButtonFormField(
          value: severity,
          items: ['Low', 'Medium', 'High', 'Critical'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setS(() => severity = v! as String),
          decoration: const InputDecoration(labelText: "Tingkat Kesulitan")
        ),
        const SizedBox(height: 15),
        TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: "Deskripsi")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
        FilledButton(onPressed: () {
           FirebaseFirestore.instance.collection('vulnerabilities').doc(item.id).update({
             'title': titleCtrl.text,
             'severity': severity,
             'description': descCtrl.text,
           });
           Navigator.pop(c);
        }, child: const Text("Simpan")),
      ],
    )));
  }

  void _deleteReportUser(String id) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Hapus Laporan?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
        TextButton(onPressed: () { 
          FirebaseFirestore.instance.collection('vulnerabilities').doc(id).delete(); 
          Navigator.pop(c); 
        }, child: const Text("Hapus", style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

// ==========================================
// 5. UI TEKNISI (RE-DESIGNED & FIXED)
// ==========================================
class TeknisiDashboard extends StatefulWidget {
  final String userName;
  final String userId;
  const TeknisiDashboard({super.key, required this.userName, required this.userId});

  @override
  State<TeknisiDashboard> createState() => _TeknisiDashboardState();
}

class _TeknisiDashboardState extends State<TeknisiDashboard> {
  int _index = 0;
  String _selectedSeverityFilter = 'All'; // State untuk Filter
  bool _isSelectionMode = false; // State untuk Mode Pilih
  final Set<String> _selectedReportIds = {}; // ID Laporan yang dipilih

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text("${_selectedReportIds.length} Dipilih") 
            : const Text("Console Teknisi"),
        centerTitle: false,
        leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(Icons.close), 
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedReportIds.clear();
                  });
                }) 
            : null,
        actions: [
          // JIKA MODE PILIH AKTIF: TAMPILKAN TOMBOL DELETE SELECTED
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: "Hapus Item Terpilih",
              onPressed: _selectedReportIds.isEmpty ? null : _confirmDeleteSelected,
            )
          // JIKA MODE NORMAL DAN DI TAB DATA/RIWAYAT: TAMPILKAN FILTER & SELECT
          else if (_index == 1 || _index == 2) ...[
            // 1. FILTER SEVERITY
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: "Filter Kesulitan",
              onSelected: (val) => setState(() => _selectedSeverityFilter = val),
              itemBuilder: (ctx) => ['All', 'Low', 'Medium', 'High', 'Critical']
                  .map((val) => PopupMenuItem(
                        value: val,
                        child: Row(
                          children: [
                            if (_selectedSeverityFilter == val) ...[
                              const Icon(Icons.check, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                            ],
                            Text(val == 'All' ? 'Semua Tingkat' : val),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            
            // 2. TOMBOL MODE PILIH (MULTI-SELECT)
            IconButton(
              icon: const Icon(Icons.checklist_rtl_rounded),
              tooltip: "Pilih Item untuk Dihapus",
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _buildOverview(),
          _buildActiveTicketList(), // Index 1: Data (Open/In Progress)
          _buildHistoryList(),      // Index 2: Riwayat (Resolved)
          _buildSettings(context),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // Reset Selection Mode saat ganti tab
          if (_isSelectionMode) {
            setState(() {
              _isSelectionMode = false;
              _selectedReportIds.clear();
            });
          }
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: "Overview"),
          NavigationDestination(icon: Icon(Icons.list_alt_rounded), label: "Data"),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: "Riwayat"),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: "Settings"),
        ],
      ),
      floatingActionButton: (!_isSelectionMode) 
        ? FloatingActionButton(
            onPressed: () => showReportDialog(context, "Admin (${widget.userName})", widget.userId),
            child: const Icon(Icons.add),
          )
        : null,
    );
  }

  // LOGIKA HAPUS ITEM TERPILIH (MULTI-DELETE)
  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Hapus ${_selectedReportIds.length} Laporan?"),
        content: const Text("Item yang dipilih akan dihapus permanen. Tindakan ini tidak bisa dibatalkan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Tutup dialog
              
              final batch = FirebaseFirestore.instance.batch();
              for (String id in _selectedReportIds) {
                batch.delete(FirebaseFirestore.instance.collection('vulnerabilities').doc(id));
              }

              await batch.commit();
              
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${_selectedReportIds.length} laporan dihapus.")));
                 setState(() {
                   _isSelectionMode = false;
                   _selectedReportIds.clear();
                 });
              }
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vulnerabilities').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        
        final docs = snapshot.data!.docs.map((d) => VulnerabilityReport.fromFirestore(d)).toList();
        docs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        int total = docs.length;
        int open = docs.where((d) => d.status == 'Open').length;
        int critical = docs.where((d) => d.severity == 'Critical').length;
        int resolved = docs.where((d) => d.status == 'Resolved').length;

        final recentDocs = docs.take(10).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Statistik Ringkas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              Row(
                children: [
                  _statCard("Total", total.toString(), Colors.blue, Icons.folder),
                  const SizedBox(width: 10),
                  _statCard("Open", open.toString(), Colors.orange, Icons.pending_actions),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statCard("Critical", critical.toString(), Colors.red, Icons.warning_rounded),
                  const SizedBox(width: 10),
                  _statCard("Selesai", resolved.toString(), Colors.green, Icons.check_circle_rounded),
                ],
              ),
              const SizedBox(height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Pemberitahuan Laporan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => setState(() => _index = 1),
                    child: const Text("Lihat Semua"),
                  )
                ],
              ),
              const SizedBox(height: 10),
              
              if (recentDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text("Belum ada laporan.", style: TextStyle(color: Colors.grey))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentDocs.length,
                  itemBuilder: (ctx, i) => _buildNotificationTile(recentDocs[i]),
                ),
                
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(VulnerabilityReport item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.notifications_active_rounded, color: Colors.blue, size: 20),
        ),
        title: Text("Laporan dari ${item.reporterName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          "${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')} • ${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year}",
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _statCard(String title, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TAMPILAN TAB "DATA" (Aktif) DENGAN FILTER & SELECTION
  Widget _buildActiveTicketList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vulnerabilities').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // 1. Filter: Status != Resolved
        var docs = snapshot.data!.docs
            .map((d) => VulnerabilityReport.fromFirestore(d))
            .where((d) => d.status != 'Resolved')
            .toList();
            
        // 2. Filter: Severity (Jika bukan 'All')
        if (_selectedSeverityFilter != 'All') {
          docs = docs.where((d) => d.severity == _selectedSeverityFilter).toList();
        }
            
        final filteredDocs = docs.toList();
        filteredDocs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
                const SizedBox(height: 10),
                Text("Tidak ada laporan ($_selectedSeverityFilter).", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (ctx, i) => _buildTicketCard(
            filteredDocs[i], 
            isAdmin: true,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedReportIds.contains(filteredDocs[i].id),
            onSelect: () => _toggleSelection(filteredDocs[i].id),
            onEdit: () => _editReport(filteredDocs[i]),
            onResolve: () => _markAsResolved(filteredDocs[i].id),
          ),
        );
      },
    );
  }

  // TAMPILAN TAB "RIWAYAT" (Selesai) DENGAN FILTER & SELECTION
  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vulnerabilities').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // 1. Filter: Status == Resolved
        var docs = snapshot.data!.docs
            .map((d) => VulnerabilityReport.fromFirestore(d))
            .where((d) => d.status == 'Resolved')
            .toList();

        // 2. Filter: Severity (Jika bukan 'All')
        if (_selectedSeverityFilter != 'All') {
          docs = docs.where((d) => d.severity == _selectedSeverityFilter).toList();
        }
            
        final filteredDocs = docs.toList();
        filteredDocs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("Belum ada riwayat sesuai filter.", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (ctx, i) => _buildTicketCard(
            filteredDocs[i], 
            isAdmin: true,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedReportIds.contains(filteredDocs[i].id),
            onSelect: () => _toggleSelection(filteredDocs[i].id),
            onEdit: () => _editReport(filteredDocs[i]),
            onResolve: () => _markAsResolved(filteredDocs[i].id),
          ),
        );
      },
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedReportIds.contains(id)) {
        _selectedReportIds.remove(id);
      } else {
        _selectedReportIds.add(id);
      }
    });
  }

  void _markAsResolved(String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Konfirmasi Perbaikan"),
        content: const Text("Tandai laporan ini sebagai Selesai (Resolved)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('vulnerabilities').doc(id).update({'status': 'Resolved'});
              if (mounted) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status diperbarui!"), backgroundColor: Colors.green));
              }
            },
            child: const Text("Ya, Selesai"),
          ),
        ],
      ),
    );
  }

  void _editReport(VulnerabilityReport item) {
    String severity = item.severity;
    String status = item.status;
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text("Update Status"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField(
          value: severity, 
          items: ['Low', 'Medium', 'High', 'Critical'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
          onChanged: (v) => setS(() => severity = v! as String), 
          decoration: const InputDecoration(labelText: "Severity")
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField(
          value: status, 
          items: ['Open', 'In Progress', 'Resolved'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
          onChanged: (v) => setS(() => status = v! as String), 
          decoration: const InputDecoration(labelText: "Status")
        ),
      ]),
      actions: [
        FilledButton(onPressed: () { FirebaseFirestore.instance.collection('vulnerabilities').doc(item.id).update({'severity': severity, 'status': status}); Navigator.pop(c); }, child: const Text("Simpan")),
      ],
    )));
  }
}

// ==========================================
// 6. SHARED WIDGETS (CARD & SETTINGS)
// ==========================================

Widget _buildTicketCard(
  VulnerabilityReport item, {
  bool isAdmin = false,
  bool isSelectionMode = false, // Mode Pilih
  bool isSelected = false,      // Apakah item ini dipilih?
  VoidCallback? onSelect,       // Callback saat dipilih
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onResolve,
}) {
  Color color;
  switch (item.severity) {
    case 'Critical': color = Colors.red; break;
    case 'High': color = Colors.orange[800]!; break;
    case 'Medium': color = Colors.orange; break;
    default: color = Colors.green;
  }

  return InkWell(
    onTap: isSelectionMode ? onSelect : null, // Jika mode pilih, tap = pilih
    borderRadius: BorderRadius.circular(12),
    child: Card(
      elevation: isSelected ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null, // Highlight jika dipilih
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: isSelectionMode
                ? Checkbox(value: isSelected, onChanged: (_) => onSelect?.call())
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, color: color),
                  ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // Deskripsi Laporan
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
                const SizedBox(height: 8),
                // Metadata (Reporter & Status)
                Row(
                  children: [
                    Icon(Icons.account_circle, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(item.reporterName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 10),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.status == 'Resolved' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.status, 
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: item.status == 'Resolved' ? Colors.green : Colors.orange
                        )
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: isAdmin && !isSelectionMode ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.status != 'Resolved')
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                    onPressed: onResolve,
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: onEdit,
                ),
                // ICON DELETE DIHAPUS DARI SINI
              ],
            ) : (!isAdmin ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(item.severity, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              ) : null), // Jika teknisi & selection mode, trailing kosong
          ),
          
          // User actions row (Hanya untuk User biasa)
          if (!isAdmin) 
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 16, color: Colors.blueGrey),
                    label: const Text("Edit", style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                    label: const Text("Hapus", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildSettings(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text("Preferensi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (ctx, mode, _) => SwitchListTile(
                title: const Text("Mode Gelap"),
                secondary: const Icon(Icons.dark_mode_rounded),
                value: mode == ThemeMode.dark,
                onChanged: (v) => themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text("Notifikasi"),
              trailing: Switch(value: true, onChanged: (v) {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: 30),
      SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
          },
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text("Keluar Akun", style: TextStyle(color: Colors.red)),
        ),
      ),
    ],
  );
}