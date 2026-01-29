import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        children: [
          // Seção de Aparência
          const _SectionHeader(title: 'Aparência'),
          
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Tema Claro'),
                    subtitle: const Text('Usar tema claro sempre'),
                    value: ThemeMode.light,
                    groupValue: themeProvider.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Tema Escuro'),
                    subtitle: const Text('Usar tema escuro sempre'),
                    value: ThemeMode.dark,
                    groupValue: themeProvider.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Automático'),
                    subtitle: const Text('Seguir configuração do sistema'),
                    value: ThemeMode.system,
                    groupValue: themeProvider.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                      }
                    },
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // Seção de Rede
          const _SectionHeader(title: 'Rede'),
          
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              return SwitchListTile(
                title: const Text('Mesh Multi-hop'),
                subtitle: const Text('Retransmitir mensagens através de outros dispositivos'),
                value: chatProvider.isMeshEnabled,
                onChanged: (value) {
                  chatProvider.toggleMesh(value);
                },
              );
            },
          ),

          const Divider(),

          // Seção de Notificações
          const _SectionHeader(title: 'Notificações'),
          
          ListTile(
            title: const Text('Solicitar Permissões'),
            subtitle: const Text('Permitir notificações push'),
            trailing: const Icon(Icons.notifications_outlined),
            onTap: () async {
              await NotificationService.requestPermissions();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Verifique as permissões nas configurações'),
                ),
              );
            },
          ),

          ListTile(
            title: const Text('Testar Notificação'),
            subtitle: const Text('Enviar notificação de teste'),
            trailing: const Icon(Icons.send),
            onTap: () {
              NotificationService.showMessageNotification(
                id: 999,
                title: 'Teste',
                body: 'Esta é uma notificação de teste!',
              );
            },
          ),

          const Divider(),

          // Seção Sobre
          const _SectionHeader(title: 'Sobre'),
          
          const ListTile(
            title: Text('Versão'),
            subtitle: Text('1.2.0'),
          ),

          ListTile(
            title: const Text('Documentação'),
            subtitle: const Text('README, MESH, ARQUITETURA'),
            trailing: const Icon(Icons.description),
            onTap: () {
              // TODO: Abrir documentação
            },
          ),

          const ListTile(
            title: Text('Desenvolvido com ❤️'),
            subtitle: Text('Speew MVP - Open Source'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
