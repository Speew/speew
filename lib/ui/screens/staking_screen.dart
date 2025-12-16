import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../core/wallet/staking/staking_service.dart';
import '../../core/wallet/staking/stake_model.dart';
import '../../core/storage/repository_pattern.dart';
import '../components/p2p_components.dart';
import '../components/app_button.dart';
import '../themes/app_theme.dart';

/// Tela de gerenciamento de Staking.
class StakingScreen extends StatefulWidget {
  final User currentUser;

  const StakingScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<StakingScreen> createState() => _StakingScreenState();
}

class _StakingScreenState extends State<StakingScreen> {
  final StakingService _stakingService = StakingService();
  late Future<List<StakeModel>> _stakesFuture;

  @override
  void initState() {
    super.initState();
    _stakesFuture = _fetchStakes();
  }

  Future<List<StakeModel>> _fetchStakes() async {
    // Simulação de busca no repositório
    return repositories.stakes.findByUserId(widget.currentUser.userId);
  }

  void _showCreateStakeDialog() {
    // TODO: Implementar diálogo para criar novo staking
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Funcionalidade de criar staking em desenvolvimento.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: FutureBuilder<List<StakeModel>>(
        future: _stakesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingIndicator(message: 'Carregando Staking...');
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          
          final stakes = snapshot.data ?? [];
          
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Resumo
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Staked',
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    TokenBadge(amount: stakes.fold(0.0, (sum, s) => sum + s.amount), symbol: 'MESH', isLarge: true),
                    SizedBox(height: 16),
                    Text(
                      'Rendimento Estimado: ${stakes.fold(0.0, (sum, s) => sum + s.calculateYield()).toStringAsFixed(2)} MESH',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              Text(
                'Meus Stakings Ativos',
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: 12),
              
              if (stakes.isEmpty)
                Center(
                  child: Text(
                    'Nenhum staking ativo. Comece a ganhar recompensas!',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                ...stakes.map((stake) => _buildStakeItem(context, stake)).toList(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateStakeDialog,
        icon: Icon(Icons.lock_open),
        label: Text('Novo Staking'),
      ),
    );
  }

  Widget _buildStakeItem(BuildContext context, StakeModel stake) {
    final theme = Theme.of(context);
    final isFinished = stake.isLockPeriodFinished();
    
    return AppCard(
      onTap: isFinished ? () => _unstake(stake.stakeId) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stake.amount.toStringAsFixed(2)} ${stake.tokenId}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryDark,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFinished ? AppTheme.success.withOpacity(0.1) : AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFinished ? 'Pronto para Retirar' : 'Ativo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isFinished ? AppTheme.success : AppTheme.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'APY: ${(stake.annualPercentageYield * 100).toStringAsFixed(1)}%',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'Rendimento: ${stake.calculateYield().toStringAsFixed(2)} ${stake.tokenId}',
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: 8),
          if (!isFinished)
            Text(
              'Fim do Bloqueio: ${stake.stakeDate.add(stake.lockDuration).toString().substring(0, 16)}',
              style: theme.textTheme.bodySmall,
            ),
          if (isFinished)
            AppButton(
              text: 'Retirar Staking',
              onPressed: () => _unstake(stake.stakeId),
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
            ),
        ],
      ),
    );
  }

  void _unstake(String stakeId) async {
    try {
      final totalReturn = await _stakingService.unstake(stakeId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Staking retirado com sucesso! Retorno total: ${totalReturn.toStringAsFixed(2)}'),
          backgroundColor: AppTheme.success,
        ),
      );
      setState(() {
        _stakesFuture = _fetchStakes();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao retirar staking: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
