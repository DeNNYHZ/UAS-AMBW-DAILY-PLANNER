import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/task_model.dart';

class TaskService {
  final _client = Supabase.instance.client;
  static const String hiveBoxName = 'tasks_box';

  Future<List<Map<String, dynamic>>> getTasks({
    String? category,
    bool? isDone,
    String? search,
    DateTime? date,
    String? priority,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      final box = await Hive.openBox<TaskModel>(hiveBoxName);
      final allTasks = box.values.where((t) => t.userId == user.id).toList();
      final filtered = allTasks
          .where((task) {
            if (category != null &&
                category.isNotEmpty &&
                task.category != category)
              return false;
            if (isDone != null && task.isDone != isDone) return false;
            if (priority != null &&
                priority.isNotEmpty &&
                task.priority != priority)
              return false;
            if (date != null &&
                task.date.toIso8601String().split('T')[0] !=
                    date.toIso8601String().split('T')[0])
              return false;
            if (search != null &&
                search.isNotEmpty &&
                !((task.title.toLowerCase().contains(search.toLowerCase())) ||
                    (task.description?.toLowerCase().contains(
                          search.toLowerCase(),
                        ) ??
                        false)))
              return false;
            return true;
          })
          .map((t) => t.toMap())
          .toList();
      return filtered;
    }
    try {
      var query = _client.from('tasks').select().eq('user_id', user.id);
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (isDone != null) {
        query = query.eq('is_done', isDone);
      }
      if (priority != null && priority.isNotEmpty) {
        query = query.eq('priority', priority);
      }
      if (date != null) {
        final dateStr = date.toIso8601String().split('T')[0];
        query = query
            .gte('date', dateStr)
            .lt(
              'date',
              date.add(const Duration(days: 1)).toIso8601String().split('T')[0],
            );
      }
      if (search != null && search.isNotEmpty) {
        query = query.or('title.ilike.%$search%,description.ilike.%$search%');
      }
      final response = await query.order('date', ascending: true);
      final box = await Hive.openBox<TaskModel>(hiveBoxName);
      await box.clear();
      for (final t in response) {
        final model = TaskModel.fromMap(Map<String, dynamic>.from(t));
        await box.put(model.id, model);
      }
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data task: ${e.toString()}');
    }
  }

  // Tambah task baru
  Future<void> addTask({
    required String title,
    required String description,
    required DateTime date,
    String? category,
    String? priority,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      final box = await Hive.openBox<TaskModel>(hiveBoxName);
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final model = TaskModel(
        id: id,
        userId: user.id,
        title: title,
        description: description,
        date: date,
        isDone: false,
        category: category ?? '',
        priority: priority ?? 'Sedang',
        synced: false,
      );
      await box.put(id, model);
      return;
    }
    try {
      await _client.from('tasks').insert({
        'user_id': user.id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'is_done': false,
        'category': category ?? '',
        'priority': priority ?? 'Sedang',
      });
    } catch (e) {
      throw Exception('Gagal menambah task: ${e.toString()}');
    }
  }

  // Update task
  Future<void> updateTask({
    required String id,
    required String title,
    required String description,
    required DateTime date,
    required bool isDone,
    String? category,
    String? priority,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      final box = await Hive.openBox<TaskModel>(hiveBoxName);
      final task = box.get(id);
      if (task != null) {
        final updated = task.copyWith(
          title: title,
          description: description,
          date: date,
          isDone: isDone,
          category: category ?? '',
          priority: priority ?? 'Sedang',
          synced: false,
        );
        await box.put(id, updated);
      }
      return;
    }
    await _client
        .from('tasks')
        .update({
          'title': title,
          'description': description,
          'date': date.toIso8601String(),
          'is_done': isDone,
          'category': category ?? '',
          'priority': priority ?? 'Sedang',
        })
        .eq('id', id);
  }

  // Hapus task
  Future<void> deleteTask(String id) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      final box = await Hive.openBox<TaskModel>(hiveBoxName);
      await box.delete(id);
      return;
    }
    await _client.from('tasks').delete().eq('id', id);
  }

  // Sync task offline ke Supabase
  Future<void> syncOfflineTasks() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;
    final box = await Hive.openBox<TaskModel>(hiveBoxName);
    final unsynced = box.values
        .where((t) => t.userId == user.id && t.synced == false)
        .toList();
    for (final task in unsynced) {
      try {
        await _client.from('tasks').insert({
          'user_id': user.id,
          'title': task.title,
          'description': task.description,
          'date': task.date.toIso8601String(),
          'is_done': task.isDone,
          'category': task.category,
          'priority': task.priority,
        });
        final updated = task.copyWith(synced: true);
        await box.put(task.id, updated);
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final response = await _client
          .from('categories')
          .select()
          .eq('user_id', user.id)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil kategori: ${e.toString()}');
    }
  }

  // Tambah kategori
  Future<void> addCategory(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('categories').insert({
      'user_id': user.id,
      'name': name.trim(),
    });
  }

  // Hapus kategori
  Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
