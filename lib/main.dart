import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_page.dart';
import 'services/task_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/profile_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/task_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'screens/onboarding_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TaskModelAdapter());

  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('mouse_tracker.dart')) return;
    FlutterError.dumpErrorToConsole(details);
  };

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  // Cek Supabase apakah sudah ada
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    print('ERROR: Supabase credentials not provided!');
    print('Please run the app with:');
    print(
      'flutter run --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL --dart-define=SUPABASE_KEY=YOUR_SUPABASE_ANON_KEY',
    );
    print('');
    print('You can find these values in your Supabase project settings:');
    print('1. Go to https://supabase.com/dashboard');
    print('2. Select your project');
    print('3. Go to Settings > API');
    print('4. Copy the "Project URL" and "anon public" key');
  }

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    print('Supabase initialized successfully');
  } catch (e) {
    print('Failed to initialize Supabase: $e');
  }

  if (!kIsWeb) {}
  runApp(const AppRoot());
}

Future<void> backgroundCallback(Uri? uri) async {
  if (uri != null && uri.host == 'addTask') {}
}

class AppRoot extends StatefulWidget {
  const AppRoot({Key? key}) : super(key: key);

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _loadingOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  /// Mengecek apakah onboarding sudah pernah ditampilkan
  Future<void> _checkOnboarding() async {
    await Hive.openBox('settings');
    setState(() {
      _loadingOnboarding = false;
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  void _onLoginSuccess() async {
    final box = await Hive.openBox('settings');
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      print('Error: User ID is null after successful login.');
      navigatorKey.currentState!.pushReplacementNamed('/auth');
      return;
    }

    final onboardingDoneKey = 'onboarding_done_$userId';
    bool hasUserCompletedOnboarding =
        box.get(onboardingDoneKey, defaultValue: false) == true;

    if (kDebugMode) {
      await box.put(onboardingDoneKey, false);
      hasUserCompletedOnboarding = false;
    }

    if (!mounted) return;

    Future.microtask(() async {
      if (!hasUserCompletedOnboarding) {
        await navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnboardingPage(
              onFinish: () async {
                // Kalo pernah melihat onboarding maka user di flag agar tidak melihat lagi
                final onboardingBox = await Hive.openBox('settings');
                await onboardingBox.put(onboardingDoneKey, true);

                if (navigatorKey.currentState != null && mounted) {
                  navigatorKey.currentState!.pushReplacementNamed('/home');
                }
              },
            ),
          ),
        );
      } else {
        // Kalo pernah onboarding page maka langsung ke home
        await navigatorKey.currentState!.pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOnboarding) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Planner',
      themeMode: _themeMode,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8AB4F8),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF2C2C2C),
        cardColor: const Color(0xFF3C3C3C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: FutureBuilder(
        future: Future.value(Supabase.instance.client.auth.currentUser),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = Supabase.instance.client.auth.currentUser;

          if (user == null) {
            return AuthPage(onLoginSuccess: _onLoginSuccess);
          } else {
            return MyHomePage(
              onToggleTheme: _toggleTheme,
              themeMode: _themeMode,
            );
          }
        },
      ),
      routes: {
        '/home': (context) =>
            MyHomePage(onToggleTheme: _toggleTheme, themeMode: _themeMode),
        '/auth': (context) => AuthPage(onLoginSuccess: _onLoginSuccess),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  const MyHomePage({
    Key? key,
    required this.onToggleTheme,
    required this.themeMode,
  }) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TaskService _taskService = TaskService();
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = '';
  bool? _filterDone;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? _profileName;
  String? _profileAvatarUrl;
  String? _profileEmail;
  bool _profileLoading = true;

  List<Map<String, dynamic>> _userCategories = [];
  bool _loadingCategories = true;

  String _searchQuery = '';
  DateTime? _filterDate;
  String? _filterPriority;
  final List<String> _priorities = ['Tinggi', 'Sedang', 'Rendah'];
  final List<Map<String, String>> _quotes = [
    {'q': 'The secret of getting ahead is getting started.', 'a': 'Mark Twain'},
    {
      'q': "Don't watch the clock; do what it does. Keep going.",
      'a': 'Sam Levenson',
    },
    {
      'q': 'Success is the sum of small efforts, repeated day in and day out.',
      'a': 'Robert Collier',
    },
    {
      'q': 'Your future is created by what you do today, not tomorrow.',
      'a': 'Robert Kiyosaki',
    },
    {'q': 'The best way to get something done is to begin.', 'a': 'Unknown'},
  ];
  late Map<String, String> _quoteOfTheDay;

  // --- THEME TOGGLE ---
  ThemeMode _themeMode = ThemeMode.system;

  // --- GLOBAL LOADING OVERLAY ---
  bool _globalLoading = false;
  void setGlobalLoading(bool value) {
    setState(() => _globalLoading = value);
  }

  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = '';
    _quoteOfTheDay = _quotes[Random().nextInt(_quotes.length)];
    _initializeNotifications();
    _fetchProfile();
    _fetchCategories();
    _fetchTasks();
    final _connectivity = Connectivity();
    _connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
    _connectivity.checkConnectivity().then((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _showDoneNotification(String title) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'done_channel',
          'Task Selesai',
          channelDescription: 'Notifikasi untuk task yang selesai',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails notifDetails = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      0,
      'Task Selesai',
      '"$title" telah ditandai selesai!',
      notifDetails,
    );
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final connectivity = await Connectivity().checkConnectivity();
    try {
      final tasks = await _taskService.getTasks(
        category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
        isDone: _filterDone,
        search: _searchQuery,
        date: _filterDate,
        priority: _filterPriority,
      );
      setState(() {
        // Jika filter kategori 'Semua', urutkan berdasarkan prioritas
        if ((_selectedCategory.isEmpty || _selectedCategory == '') &&
            (_filterPriority == null || _filterPriority!.isEmpty)) {
          final priorityOrder = {'Tinggi': 0, 'Sedang': 1, 'Rendah': 2};
          tasks.sort((a, b) {
            final pa = priorityOrder[a['priority']] ?? 1;
            final pb = priorityOrder[b['priority']] ?? 1;
            if (pa != pb) return pa.compareTo(pb);
            // Jika prioritas sama, urutkan berdasarkan tanggal
            return (a['date'] ?? '').compareTo(b['date'] ?? '');
          });
        }
        _tasks = tasks;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        if (connectivity != ConnectivityResult.none) {
          _error = e.toString();
        } else {
          _error = null;
        }
      });
    }
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final response = await Supabase.instance.client
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    setState(() {
      _profileName = response != null ? response['name'] as String? : null;
      _profileAvatarUrl = response != null
          ? response['avatar_url'] as String?
          : null;
      _profileEmail = user.email;
      _profileLoading = false;
    });
  }

  Future<void> _fetchCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final cats = await _taskService.getCategories();
      setState(() {
        _userCategories = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _userCategories = [];
        _loadingCategories = false;
      });
    }
  }

  Future<void> _addCategoryDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nama kategori'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _taskService.addCategory(controller.text.trim());
                Navigator.pop(context);
                _fetchCategories();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kategori ditambahkan')),
                  );
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategoryByName(String name) async {
    final cat = _userCategories.firstWhere(
      (c) => c['name'] == name,
      orElse: () => <String, dynamic>{},
    );
    if (cat.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Yakin ingin menghapus kategori "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _taskService.deleteCategory(cat['id']);
      await _fetchCategories();
      _fetchTasks();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kategori dihapus')));
    }
  }

  void _showTaskDialog({Map<String, dynamic>? task}) {
    final titleController = TextEditingController(text: task?['title'] ?? '');
    final descController = TextEditingController(
      text: task?['description'] ?? '',
    );
    String selectedCategory = task?['category'] ?? '';
    String selectedPriority = task?['priority'] ?? 'Sedang';
    DateTime selectedDate = task != null
        ? DateTime.parse(task['date'])
        : DateTime.now();
    bool isEdit = task != null;
    bool showError = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              shrinkWrap: true,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Text(
                  isEdit ? 'Edit Task' : 'Tambah Task',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  style: GoogleFonts.poppins(),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  style: GoogleFonts.poppins(),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  items: _priorities
                      .map(
                        (p) =>
                            DropdownMenuItem<String>(value: p, child: Text(p)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setModalState(() {
                      selectedPriority = val ?? 'Sedang';
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Prioritas',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory.isNotEmpty ? selectedCategory : '',
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Semua'),
                    ),
                    ..._userCategories.map(
                      (cat) => DropdownMenuItem<String>(
                        value: cat['name'] as String,
                        child: Text(cat['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setModalState(() {
                      selectedCategory = val ?? '';
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tanggal:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        '${selectedDate.toLocal()}'.split(' ')[0],
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) {
                            setModalState(() {
                              showError = true;
                            });
                            return;
                          }
                          try {
                            if (isEdit) {
                              await _taskService.updateTask(
                                id: task!['id'],
                                title: titleController.text.trim(),
                                description: descController.text.trim(),
                                date: selectedDate,
                                isDone: task['is_done'] ?? false,
                                category: selectedCategory.isEmpty
                                    ? null
                                    : selectedCategory,
                                priority: selectedPriority,
                              );
                            } else {
                              await _taskService.addTask(
                                title: titleController.text.trim(),
                                description: descController.text.trim(),
                                date: selectedDate,
                                category: selectedCategory.isEmpty
                                    ? null
                                    : selectedCategory,
                                priority: selectedPriority,
                              );
                            }
                            if (mounted) Navigator.pop(context);
                            setState(() {
                              _loading = true;
                            });
                            await _fetchTasks();
                            setState(() {
                              _loading = false;
                            });
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Task diperbarui'
                                        : 'Task ditambahkan',
                                  ),
                                ),
                              );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal menambah task: \n${e.toString()}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  backgroundColor: Colors.white,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(isEdit ? 'Update' : 'Tambah'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleDone(Map<String, dynamic> task) async {
    final newDone = !(task['is_done'] ?? false);
    try {
      await _taskService.updateTask(
        id: task['id'],
        title: task['title'],
        description: task['description'],
        date: DateTime.parse(task['date']),
        isDone: newDone,
        category: task['category'],
      );
      if (newDone) {
        try {
          await _showDoneNotification(task['title'] ?? '');
        } catch (e) {
          print('Error showing notification: $e');
        }
      }
      _fetchTasks();
    } catch (e) {
      print('Error toggling task done status: $e');
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Task'),
        content: const Text('Yakin ingin menghapus task ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _taskService.deleteTask(taskId);
      _fetchTasks();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task dihapus')));
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        final box = await Hive.openBox('settings');
        await box.put('onboarding_done', false);
        navigatorKey.currentState!.pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          'Daily Planner',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 38),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Dark Mode',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 400),
            offset: _isOnline ? const Offset(0, -1) : Offset.zero,
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _isOnline ? 0 : 1,
              child: _isOnline
                  ? const SizedBox.shrink()
                  : Container(
                      width: double.infinity,
                      color: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Offline - Perubahan akan disimpan lokal',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Icon(
                            Icons.format_quote,
                            color: Colors.white70,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '"${_quoteOfTheDay['q']}"',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '- ${_quoteOfTheDay['a']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfilePage(onProfileUpdated: _fetchProfile),
                          ),
                        );
                        _fetchProfile();
                      },
                      child: Row(
                        children: [
                          _profileLoading
                              ? const CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white24,
                                )
                              : (_profileAvatarUrl != null &&
                                    _profileAvatarUrl!.isNotEmpty)
                              ? CircleAvatar(
                                  radius: 22,
                                  backgroundImage: NetworkImage(
                                    _profileAvatarUrl!,
                                  ),
                                )
                              : const CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white24,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              'Hello, ${(_profileName != null && _profileName!.trim().isNotEmpty) ? _profileName : (_profileEmail ?? 'User')}',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kategori',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('Semua'),
                              ),
                              ..._userCategories.map(
                                (cat) => DropdownMenuItem<String>(
                                  value: cat['name'] as String,
                                  child: Text(cat['name'] as String),
                                ),
                              ),
                            ],
                            onChanged: (val) async {
                              setState(() {
                                _selectedCategory = val ?? '';
                              });
                              _fetchTasks();
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            await _addCategoryDialog();
                            await _fetchCategories();
                          },
                          icon: const Icon(Icons.add),
                          tooltip: 'Tambah Kategori',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<bool?>(
                      value: _filterDone,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Semua')),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Belum Selesai'),
                        ),
                        DropdownMenuItem(value: true, child: Text('Selesai')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _filterDone = val;
                        });
                        _fetchTasks();
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari task... (judul/deskripsi)',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 12,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                          _fetchTasks();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filter tanggal
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      tooltip: 'Filter tanggal',
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        setState(() {
                          _filterDate = picked;
                        });
                        _fetchTasks();
                      },
                    ),
                    // Filter prioritas
                    DropdownButton<String>(
                      value: _filterPriority,
                      hint: const Text('Prioritas'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Semua'),
                        ),
                        ..._priorities.map(
                          (p) => DropdownMenuItem(value: p, child: Text(p)),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _filterPriority = val;
                        });
                        _fetchTasks();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/empty_tasks.svg',
                              height: 120,
                              width: 120,
                              fit: BoxFit.contain,
                              placeholderBuilder: (context) => Icon(
                                Icons.inbox,
                                size: 80,
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada task',
                              style: TextStyle(
                                color: Theme.of(context).disabledColor,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        itemBuilder: (context, i) {
                          final task = _tasks[i];
                          return Dismissible(
                            key: ValueKey(task['id']),
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 24),
                              color: Colors.green.withOpacity(0.7),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: Colors.red.withOpacity(0.7),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                await _toggleDone(task);
                                return false;
                              } else if (direction ==
                                  DismissDirection.endToStart) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Hapus Task'),
                                    content: const Text(
                                      'Yakin ingin menghapus task ini?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteTask(task['id']);
                                  return true;
                                }
                                return false;
                              }
                              return false;
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Card(
                                key: ValueKey(task['id']),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  title: Row(
                                    children: [
                                      if (task['priority'] == 'Tinggi')
                                        const Icon(
                                          Icons.priority_high,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      if (task['priority'] == 'Sedang')
                                        const Icon(
                                          Icons.trending_up,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                      if (task['priority'] == 'Rendah')
                                        const Icon(
                                          Icons.low_priority,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          task['title'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            decoration:
                                                (task['is_done'] ?? false)
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: (task['is_done'] ?? false)
                                                ? Colors.green[900]
                                                : Theme.of(
                                                    context,
                                                  ).textTheme.titleLarge?.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((task['category'] ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Chip(
                                            label: Text(task['category']),
                                            backgroundColor: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.1),
                                          ),
                                        ),
                                      Text(
                                        task['description'] ?? '',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        'Tanggal: ${task['date']?.toString().split(' ')[0] ?? ''}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  leading: Checkbox(
                                    value: task['is_done'] ?? false,
                                    onChanged: (_) => _toggleDone(task),
                                    activeColor: Colors.green,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.orange,
                                        ),
                                        onPressed: () =>
                                            _showTaskDialog(task: task),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _deleteTask(task['id']),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_globalLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          backgroundColor: Theme.of(context).primaryColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: () {
            _showTaskDialog();
          },
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
