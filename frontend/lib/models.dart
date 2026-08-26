class TaskData {
  const TaskData({
    required this.id,
    required this.title,
    required this.status,
    required this.totalDurationSeconds,
  });

  factory TaskData.fromJson(Map<String, dynamic> json) => TaskData(
    id: json['id'] as String,
    title: json['title'] as String,
    status: json['status'] as String,
    totalDurationSeconds: json['total_duration_seconds'] as int,
  );

  final String id;
  final String title;
  final String status;
  final int totalDurationSeconds;
}

class DayData {
  const DayData({
    required this.date,
    required this.tasks,
    required this.activeTask,
    required this.totalDurationSeconds,
  });

  factory DayData.fromJson(Map<String, dynamic> json) => DayData(
    date: DateTime.parse(json['date'] as String),
    tasks: (json['tasks'] as List<dynamic>)
        .map((item) => TaskData.fromJson(item as Map<String, dynamic>))
        .toList(),
    activeTask: json['active_task'] == null
        ? null
        : TaskData.fromJson(json['active_task'] as Map<String, dynamic>),
    totalDurationSeconds: json['total_duration_seconds'] as int,
  );

  final DateTime date;
  final List<TaskData> tasks;
  final TaskData? activeTask;
  final int totalDurationSeconds;
}

class ConfirmationData {
  const ConfirmationData({required this.groupId, this.actionId});

  factory ConfirmationData.fromJson(Map<String, dynamic> json) =>
      ConfirmationData(
        groupId: json['group_id'] as String,
        actionId: json['action_id'] as String?,
      );

  final String groupId;
  final String? actionId;

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    if (actionId != null) 'action_id': actionId,
  };
}

class CommandResult {
  const CommandResult({
    required this.status,
    required this.message,
    required this.requiresConfirmation,
    this.clarificationQuestion,
    this.confirmation,
  });

  factory CommandResult.fromJson(Map<String, dynamic> json) => CommandResult(
    status: json['status'] as String,
    message: json['message'] as String,
    requiresConfirmation: json['requires_confirmation'] as bool? ?? false,
    clarificationQuestion: json['clarification_question'] as String?,
    confirmation: json['confirmation_context'] == null
        ? null
        : ConfirmationData.fromJson(
            json['confirmation_context'] as Map<String, dynamic>,
          ),
  );

  final String status;
  final String message;
  final bool requiresConfirmation;
  final String? clarificationQuestion;
  final ConfirmationData? confirmation;
}
