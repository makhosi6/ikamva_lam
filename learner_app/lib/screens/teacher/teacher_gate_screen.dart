import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/constrained_content.dart';
import '../../widgets/ikamva_app_bar_title.dart';

/// Simple PIN gate for shared tablets (TASKS §13.1).
class TeacherGateScreen extends StatefulWidget {
  const TeacherGateScreen({super.key});

  static const defaultPin = '4242';

  @override
  State<TeacherGateScreen> createState() => _TeacherGateScreenState();
}

class _TeacherGateScreenState extends State<TeacherGateScreen> {
  final _pin = TextEditingController();
  String? _error;

  void _submit() {
    if (_pin.text.trim() == TeacherGateScreen.defaultPin) {
      context.go('/teacher/home');
    } else {
      setState(() => _error = 'Incorrect PIN');
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Teacher/Parent mode', logoHeight: 28),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the Teacher/Parent PIN for this device. Default demo PIN is 4242.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN'),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: const Text('Unlock')),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to learner hub'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
