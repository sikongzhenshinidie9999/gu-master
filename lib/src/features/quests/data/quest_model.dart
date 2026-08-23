import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'quest_model.g.dart';

@HiveType(typeId: 0)
class QuestModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int tier; // 1, 2, or 3

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime? acceptedAt;

  @HiveField(6)
  bool isCompleted;

  @HiveField(7)
  bool isFailed;

  // @HiveField(8) was emoji - deprecated
  
  @HiveField(9)
  final String category;

  QuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.createdAt,
    String? category, 
    this.acceptedAt,
    this.isCompleted = false,
    this.isFailed = false,
  }) : category = category ?? 'General'; 

  bool get isActive => acceptedAt != null && !isCompleted && !isFailed;

  int get xpReward {
    switch (tier) {
      case 1: return 10;
      case 2: return 25;
      case 3: return 50;
      default: return 10;
    }
  }

  IconData get icon {
    switch (category.toLowerCase()) {
      case '炼体':
        return Icons.fitness_center_rounded;
      case '炼气':
        return Icons.air_rounded;
      case '炼神':
        return Icons.self_improvement_rounded;
      case '炼蛊':
        return Icons.bug_report_rounded;
      case '悟道':
        return Icons.auto_awesome_rounded;
      case '杂务':
        return Icons.cleaning_services_rounded;
      default:
        // Fallback for any old data or unmapped categories
        return Icons.star_rounded;
    }
  }
  
  Color get categoryColor {
    switch (category.toLowerCase()) {
      case '炼体':
        return Colors.redAccent;
      case '炼气':
        return Colors.lightBlueAccent;
      case '炼神':
        return Colors.deepPurpleAccent;
      case '炼蛊':
        return Colors.greenAccent;
      case '悟道':
        return Colors.amberAccent;
      case '杂务':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  DateTime? get expiryTime {
    if (acceptedAt == null) return null;
    return acceptedAt!.add(const Duration(hours: 24));
  }

  QuestModel copyWith({
    String? id,
    String? title,
    String? description,
    int? tier,
    DateTime? createdAt,
    DateTime? acceptedAt,
    bool? isCompleted,
    bool? isFailed,
    String? category,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tier: tier ?? this.tier,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isFailed: isFailed ?? this.isFailed,
      category: category ?? this.category,
    );
  }
}
