import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';
import 'session_store.dart';

void main() => runApp(const JubileuApp());

class JubileuApp extends StatefulWidget {
  const JubileuApp({super.key});

  @override
  State<JubileuApp> createState() => _JubileuAppState();
}

class _JubileuAppState extends State<JubileuApp> {
  final _store = SessionStore();
  String? _token;
  String? _username;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _store.readToken();
    if (token != null) {
      try {
        final username = await ApiClient(token: token).validateSession();
        if (mounted) {
          setState(() {
            _token = token;
            _username = username;
          });
        }
      } on ApiException {
        await _store.clear();
      }
    }
    if (mounted) {
      setState(() => _restoring = false);
    }
  }

  Future<void> _onLogin(LoginData data) async {
    await _store.save(token: data.token, username: data.username);
    if (mounted) {
      setState(() {
        _token = data.token;
        _username = data.username;
      });
    }
  }

  Future<void> _onLogout() async {
    final token = _token;
    if (token != null) {
      try {
        await ApiClient(token: token).logout();
      } on ApiException {
        /* Remove the local session even offline. */
      }
    }
    await _store.clear();
    if (mounted) {
      setState(() {
        _token = null;
        _username = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Jubileu',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF216869)),
      scaffoldBackgroundColor: const Color(0xFFF7FAF9),
      useMaterial3: true,
    ),
    home: _restoring
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _token == null
        ? LoginPage(onLogin: _onLogin)
        : DayPage(
            api: ApiClient(token: _token),
            username: _username ?? 'Samuel',
            onLogout: _onLogout,
          ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});
  final Future<void> Function(LoginData) onLogin;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController(text: 'Samuel');
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onLogin(
        await ApiClient().login(_username.text.trim(), _password.text),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Projeto Jubileu',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seu registro diário, com clareza e sem julgamentos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Usuário'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class DayPage extends StatefulWidget {
  const DayPage({
    super.key,
    required this.api,
    required this.username,
    required this.onLogout,
  });
  final ApiClient api;
  final String username;
  final Future<void> Function() onLogout;
  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  final _command = TextEditingController();
  DayData? _day;
  DateTime _selectedDate = DateTime.now();
  DateTime? _loadedAt;
  ConfirmationData? _confirmation;
  String? _notice;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  late final Timer _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _day?.activeTask != null) setState(() {});
    });
    _loadDay();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _command.dispose();
    super.dispose();
  }

  Future<void> _loadDay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getDay(_selectedDate);
      if (mounted) {
        setState(() {
          _day = data;
          _loadedAt = DateTime.now();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(
    String transcript, {
    ConfirmationData? confirmation,
  }) async {
    if (transcript.trim().isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _notice = null;
      _error = null;
    });
    try {
      final result = await widget.api.sendCommand(
        transcript.trim(),
        confirmation: confirmation,
      );
      if (!mounted) return;
      setState(() {
        _notice = result.clarificationQuestion ?? result.message;
        _confirmation = result.requiresConfirmation
            ? result.confirmation
            : null;
        _command.clear();
      });
      await _loadDay();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int get _activeSeconds => _day?.activeTask == null || _loadedAt == null
      ? 0
      : _day!.activeTask!.totalDurationSeconds +
            DateTime.now().difference(_loadedAt!).inSeconds;
  int get _daySeconds =>
      (_day?.totalDurationSeconds ?? 0) +
      (_day?.activeTask == null || _loadedAt == null
          ? 0
          : DateTime.now().difference(_loadedAt!).inSeconds);
  void _changeDay(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadDay();
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jubileu'),
        actions: [
          IconButton(
            onPressed: _loadDay,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDay,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Olá, ${widget.username}.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text('Registre o que está fazendo e acompanhe seu dia.'),
              const SizedBox(height: 20),
              _DateNavigator(
                date: _selectedDate,
                onPrevious: () => _changeDay(-1),
                onNext: () => _changeDay(1),
                onToday: () {
                  setState(() => _selectedDate = DateTime.now());
                  _loadDay();
                },
              ),
              const SizedBox(height: 16),
              if (_error != null)
                _MessageCard(
                  message: _error!,
                  color: Theme.of(context).colorScheme.errorContainer,
                ),
              if (_notice != null)
                _MessageCard(
                  message: _notice!,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
              if (_confirmation != null)
                _ConfirmationCard(
                  onConfirm: () =>
                      _send('confirmo', confirmation: _confirmation),
                  onCancel: () => _send('cancelo', confirmation: _confirmation),
                ),
              if (_error != null || _notice != null || _confirmation != null)
                const SizedBox(height: 12),
              if (_loading && day == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _ActiveCard(
                  task: day?.activeTask,
                  activeSeconds: _activeSeconds,
                  daySeconds: _daySeconds,
                  onPause: day?.activeTask == null
                      ? null
                      : () => _send('pausar ${day!.activeTask!.title}'),
                ),
                const SizedBox(height: 16),
                _CommandComposer(
                  controller: _command,
                  sending: _sending,
                  onSend: () => _send(_command.text),
                ),
                const SizedBox(height: 24),
                Text('Tarefas', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (day == null || day.tasks.isEmpty)
                  const _EmptyTasks()
                else
                  ...day.tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TaskCard(
                        task: task,
                        onAction:
                            task.status == 'pending' && day.activeTask == null
                            ? () => _send('iniciar ${task.title}')
                            : task.status == 'paused' && day.activeTask == null
                            ? () => _send('retomar ${task.title}')
                            : null,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
      Expanded(
        child: Text(
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      TextButton(onPressed: onToday, child: const Text('Hoje')),
    ],
  );
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.task,
    required this.activeSeconds,
    required this.daySeconds,
    this.onPause,
  });
  final TaskData? task;
  final int activeSeconds;
  final int daySeconds;
  final VoidCallback? onPause;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task == null ? 'Nenhuma tarefa em andamento' : 'Em andamento agora',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            task?.title ?? 'Escolha uma tarefa pendente para começar.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            task == null
                ? 'Total do dia: ${_duration(daySeconds)}'
                : _duration(activeSeconds),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          if (task != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onPause,
                icon: const Icon(Icons.pause),
                label: const Text('Pausar'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CommandComposer extends StatelessWidget {
  const _CommandComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comando por texto',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'A captura de voz entra depois; por enquanto este campo simula a transcrição.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(
              hintText: 'Ex.: criar tarefa Revisar orçamento',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Enviar comando'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.onAction});
  final TaskData task;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(_statusIcon(task.status)),
      title: Text(task.title),
      subtitle: Text(
        '${_statusLabel(task.status)} • ${_duration(task.totalDurationSeconds)}',
      ),
      trailing: onAction == null
          ? null
          : IconButton(
              onPressed: onAction,
              tooltip: task.status == 'paused' ? 'Retomar' : 'Iniciar',
              icon: Icon(
                task.status == 'paused'
                    ? Icons.play_circle_outline
                    : Icons.play_arrow,
              ),
            ),
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: task.notes.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nenhuma observação registrada.'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Observações',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    ...task.notes.map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2, right: 8),
                              child: Icon(Icons.chat_bubble_outline, size: 16),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(note.content),
                                  const SizedBox(height: 2),
                                  Text(
                                    _noteDate(note.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.onConfirm, required this.onCancel});
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirma esta criação?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A ação só será registrada depois da sua confirmação explícita.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: onConfirm,
                child: const Text('Confirmar'),
              ),
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.color});
  final String message;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
  );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: Text('Ainda não há tarefas para este dia.')),
    ),
  );
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remaining = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}

String _noteDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} às ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

IconData _statusIcon(String status) => switch (status) {
  'pending' => Icons.radio_button_unchecked,
  'in_progress' => Icons.play_circle_filled,
  'paused' => Icons.pause_circle_outline,
  _ => Icons.check_circle_outline,
};
String _statusLabel(String status) => switch (status) {
  'pending' => 'Pendente',
  'in_progress' => 'Em andamento',
  'paused' => 'Pausada',
  _ => 'Concluída',
};
