import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'models.dart';
import 'session_store.dart';
import 'voice_capture.dart';

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
    theme: JubileuTheme.dark(),
    home: AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      child: _restoring
          ? const Scaffold(
              key: ValueKey('loading'),
              body: AppCanvas(
                child: Center(
                  child: CircularProgressIndicator(color: JubileuPalette.mint),
                ),
              ),
            )
          : _token == null
          ? LoginPage(key: const ValueKey('login'), onLogin: _onLogin)
          : DayPage(
              key: const ValueKey('day'),
              api: ApiClient(token: _token),
              username: _username ?? 'Samuel',
              onLogout: _onLogout,
            ),
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
  Widget build(BuildContext context) => Theme(
    data: JubileuTheme.login(context),
    child: Scaffold(
      body: Container(
        color: JubileuPalette.cream,
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.92, end: 1),
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: Opacity(opacity: value, child: child),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LoginIllustration()),
                    const SizedBox(height: 12),
                    Text(
                      'Bem-vindo ao\nJubileu',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Organize o seu trabalho com mais presença e menos ruído.',
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
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continuar'),
                    ),
                  ],
                ),
              ),
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
  final _voice = VoiceCapture();
  DayData? _day;
  DateTime _selectedDate = DateTime.now();
  DateTime? _loadedAt;
  ConfirmationData? _confirmation;
  String? _notice;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  bool _transcribing = false;
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
    _voice.dispose();
    super.dispose();
  }

  Future<void> _startVoice() async {
    if (_sending || _transcribing || _recording) return;
    try {
      await _voice.start();
      if (mounted) {
        setState(() {
          _recording = true;
          _notice = 'Ouvindo… solte quando terminar.';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _stopVoice() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _transcribing = true;
      _notice = 'Transcrevendo localmente…';
    });
    try {
      final transcript = await _voice.stopAndTranscribe(widget.api);
      if (!mounted) return;
      setState(() {
        _command.text = transcript;
        _notice =
            'Entendi: “$transcript”. Revise se necessário e clique em Registrar.';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
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
        _confirmation = result.requiresConfirmation
            ? result.confirmation
            : null;
        _notice = result.requiresConfirmation
            ? null
            : result.clarificationQuestion ?? result.message;
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Row(
          children: [
            JubileuMark(small: true),
            SizedBox(width: 10),
            Text('Jubileu'),
          ],
        ),
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
      body: AppCanvas(
        child: SafeArea(
          child: _DashboardFrame(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: RefreshIndicator(
                  onRefresh: _loadDay,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Seu foco, ${widget.username}.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Escolha o que importa e deixe o tempo contar a história.',
                                ),
                              ],
                            ),
                          ),
                          const _StatusSeal(),
                        ],
                      ),
                      const SizedBox(height: 28),
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _error != null
                            ? _MessageCard(
                                key: const ValueKey('error'),
                                message: _error!,
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                              )
                            : _confirmation != null
                            ? _ConfirmationCard(
                                key: const ValueKey('confirmation'),
                                onConfirm: () => _send(
                                  'confirmo',
                                  confirmation: _confirmation,
                                ),
                                onCancel: () => _send(
                                  'cancelo',
                                  confirmation: _confirmation,
                                ),
                              )
                            : _notice != null
                            ? _MessageCard(
                                key: const ValueKey('notice'),
                                message: _notice!,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (_error != null ||
                          _notice != null ||
                          _confirmation != null)
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
                        const SizedBox(height: 18),
                        _CommandComposer(
                          controller: _command,
                          sending: _sending,
                          recording: _recording,
                          transcribing: _transcribing,
                          onSend: () => _send(_command.text),
                          onVoiceStart: _startVoice,
                          onVoiceStop: _stopVoice,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Text(
                              'Tarefas',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Text(
                              '${day?.tasks.length ?? 0} no dia',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (day == null || day.tasks.isEmpty)
                          const _EmptyTasks()
                        else
                          ...day.tasks.map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TaskCard(
                                task: task,
                                onAction:
                                    task.status == 'pending' &&
                                        day.activeTask == null
                                    ? () => _send('iniciar ${task.title}')
                                    : task.status == 'paused' &&
                                          day.activeTask == null
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
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardFrame extends StatelessWidget {
  const _DashboardFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        if (constraints.maxWidth >= 900) const _Sidebar(),
        Expanded(child: child),
      ],
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) => Container(
    width: 216,
    margin: const EdgeInsets.fromLTRB(20, 12, 0, 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E23),
      border: Border.all(color: JubileuPalette.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            JubileuMark(small: true),
            SizedBox(width: 10),
            Text('Jubileu', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 38),
        const _NavItem(
          icon: Icons.grid_view_rounded,
          label: 'Meu dia',
          active: true,
        ),
        const _NavItem(icon: Icons.checklist_rounded, label: 'Registros'),
        const _NavItem(icon: Icons.auto_graph_rounded, label: 'Insights'),
        const Spacer(),
        const Divider(color: JubileuPalette.line),
        const SizedBox(height: 10),
        Text(
          'LOCAL • PRIVADO',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: JubileuPalette.muted),
        ),
        const SizedBox(height: 8),
        Text(
          'Seus dados ficam neste computador.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: active ? JubileuPalette.panelRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: active ? JubileuPalette.mint : JubileuPalette.muted,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: active ? JubileuPalette.ink : JubileuPalette.muted,
            fontWeight: active ? FontWeight.w500 : FontWeight.w300,
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.65),
      border: Border.all(color: JubileuPalette.line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
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
        FilledButton.tonal(
          onPressed: onToday,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
          child: const Text('Hoje'),
        ),
      ],
    ),
  );
}

class _StatusSeal extends StatelessWidget {
  const _StatusSeal();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: JubileuPalette.panelRaised,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: JubileuPalette.mint),
        SizedBox(width: 7),
        Text(
          'RITMO DIÁRIO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.05,
          ),
        ),
      ],
    ),
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
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [JubileuPalette.panelRaised, Color(0xFF303039)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task == null ? 'Nenhuma tarefa em andamento' : 'Em andamento agora',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: JubileuPalette.lilac),
          ),
          const SizedBox(height: 8),
          Text(
            task?.title ?? 'Escolha uma tarefa pendente para começar.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            task == null
                ? 'Total do dia: ${_duration(daySeconds)}'
                : _duration(activeSeconds),
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            task == null
                ? 'Tempo registrado no dia'
                : 'Tempo dedicado nesta tarefa',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          if (task != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onPause,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: JubileuPalette.darkInk,
                ),
                icon: const Icon(Icons.pause_rounded),
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
    required this.recording,
    required this.transcribing,
    required this.onSend,
    required this.onVoiceStart,
    required this.onVoiceStop,
  });
  final TextEditingController controller;
  final bool sending;
  final bool recording;
  final bool transcribing;
  final VoidCallback onSend;
  final Future<void> Function() onVoiceStart;
  final Future<void> Function() onVoiceStop;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REGISTRAR AGORA',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Escreva ou segure o microfone. O áudio é transcrito neste computador.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Ex.: criar tarefa Revisar orçamento',
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Listener(
                onPointerDown: sending || transcribing
                    ? null
                    : (_) => onVoiceStart(),
                onPointerUp: recording ? (_) => onVoiceStop() : null,
                onPointerCancel: recording ? (_) => onVoiceStop() : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: recording
                        ? const Color(0xFFB94A57)
                        : JubileuPalette.panelRaised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: recording
                          ? const Color(0xFFFF8E9A)
                          : JubileuPalette.line,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        transcribing
                            ? 'Transcrevendo…'
                            : recording
                            ? 'Gravando… solte'
                            : 'Segure para falar',
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: sending || transcribing ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
                label: const Text('Registrar'),
              ),
            ],
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
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      childrenPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _statusColor(task.status).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          _statusIcon(task.status),
          color: _statusColor(task.status),
          size: 20,
        ),
      ),
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
  const _ConfirmationCard({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF9ED),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirma esta criação?',
            style: Theme.of(context).textTheme.titleMedium,
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
  const _MessageCard({super.key, required this.message, required this.color});
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
      padding: EdgeInsets.all(34),
      child: Column(
        children: [
          Icon(Icons.spa_outlined, size: 30, color: JubileuPalette.lilac),
          SizedBox(height: 10),
          Text('Um dia livre para começar com intenção.'),
        ],
      ),
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
Color _statusColor(String status) => switch (status) {
  'pending' => JubileuPalette.lilac,
  'in_progress' => JubileuPalette.mint,
  'paused' => const Color(0xFF69756D),
  _ => const Color(0xFF3B7A57),
};
String _statusLabel(String status) => switch (status) {
  'pending' => 'Pendente',
  'in_progress' => 'Em andamento',
  'paused' => 'Pausada',
  _ => 'Concluída',
};
