import 'package:hive/hive.dart';
part 'task_model.g.dart';

@HiveType(typeId: 0)
class TaskModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String? description;
  @HiveField(4)
  final DateTime date;
  @HiveField(5)
  final bool isDone;
  @HiveField(6)
  final String category;
  @HiveField(7)
  final String priority;
  @HiveField(8)
  final bool synced;

  TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.date,
    required this.isDone,
    required this.category,
    required this.priority,
    required this.synced,
  });

  TaskModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? date,
    bool? isDone,
    String? category,
    String? priority,
    bool? synced,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isDone: isDone ?? this.isDone,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'is_done': isDone,
      'category': category,
      'priority': priority,
      'synced': synced,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      isDone: map['is_done'] as bool,
      category: map['category'] as String? ?? '',
      priority: map['priority'] as String? ?? 'Sedang',
      synced: map['synced'] as bool? ?? true,
    );
  }
}
