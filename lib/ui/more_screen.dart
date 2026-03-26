import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

/// Full-screen "More" hub providing profile summary, promos, My Impact stats,
/// and quick-access service grids.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _impactTabController;

  @override
  void initState() {
    super.initState();
    _impactTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _impactTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceLG),
        children: [
          // ── Profile header card ─────────────────────────────────────────
          const _ProfileHeaderCard(),
          // ── Membership promo card ───────────────────────────────────────
          const _MembershipPromoCard(),
          // ── Fuel discounts promo card ───────────────────────────────────
          const _FuelDiscountsCard(),
          // ── My Impact section ───────────────────────────────────────────
          _MyImpactSection(tabController: _impactTabController),
          // ── Services grid ───────────────────────────────────────────────
          const _ServicesSectionGrid(),
          // ── More grid ───────────────────────────────────────────────────
          const _MoreSectionGrid(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile header card
// ---------------------------------------------------------------------------

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        AppTheme.spaceMD,
        AppTheme.spaceMD,
        AppTheme.spaceSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    size: 30,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                // Name
                Expanded(
                  child: Text(
                    'Driver',
                    style: tt.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Edit icon
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit profile',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(
                  icon: Icons.stars_rounded,
                  value: '0',
                  label: 'My Points',
                  iconColor: cs.primary,
                ),
                _ProfileStat(
                  icon: Icons.volunteer_activism_rounded,
                  value: '0',
                  label: 'Contributions',
                  iconColor: cs.secondary,
                ),
                _ProfileStat(
                  icon: Icons.contacts_rounded,
                  value: '0',
                  label: 'Address Book',
                  iconColor: cs.tertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: AppTheme.spaceXS),
        Text(value, style: tt.titleMedium),
        Text(label, style: tt.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Membership promo card
// ---------------------------------------------------------------------------

class _MembershipPromoCard extends StatelessWidget {
  const _MembershipPromoCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      color: cs.primaryContainer,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceMD,
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                size: 36,
                color: cs.onPrimaryContainer,
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gud Express LLC',
                      style: tt.titleSmall
                          ?.copyWith(color: cs.onPrimaryContainer),
                    ),
                    Text(
                      'Enter VIP Center',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fuel discounts promo card
// ---------------------------------------------------------------------------

class _FuelDiscountsCard extends StatelessWidget {
  const _FuelDiscountsCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get Instant Fuel Discounts',
                    style: tt.titleSmall,
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    'Save up to 80¢/gal. No credit check. No fees.',
                    style: tt.bodySmall,
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Go Check'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Icon(
              Icons.local_gas_station_rounded,
              size: 52,
              color: cs.primary.withAlpha(128),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Impact section
// ---------------------------------------------------------------------------

class _MyImpactSection extends StatelessWidget {
  const _MyImpactSection({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceXS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Impact', style: tt.titleMedium),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New'),
              ),
            ],
          ),
        ),
        // Tab bar
        TabBar(
          controller: tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface,
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'Reviews'),
            Tab(text: 'Q&As'),
            Tab(text: 'Updates'),
          ],
        ),
        // Tab content (fixed height)
        SizedBox(
          height: 110,
          child: TabBarView(
            controller: tabController,
            children: [
              // Reviews tab
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD,
                  vertical: AppTheme.spaceSM,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ImpactStatCard(
                        icon: Icons.visibility_rounded,
                        label: 'Views',
                        value: '0',
                        iconColor: cs.primary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: _ImpactStatCard(
                        icon: Icons.thumb_up_rounded,
                        label: 'Likes',
                        value: '0',
                        iconColor: cs.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Q&As tab
              Center(
                child: Text('No Q&As yet', style: tt.bodyMedium),
              ),
              // Updates tab
              Center(
                child: Text('No Updates yet', style: tt.bodyMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImpactStatCard extends StatelessWidget {
  const _ImpactStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHigh,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceSM),
        child: Row(
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(width: AppTheme.spaceSM),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: tt.titleMedium),
                Text(label, style: tt.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Services grid
// ---------------------------------------------------------------------------

class _ServicesSectionGrid extends StatelessWidget {
  const _ServicesSectionGrid();

  static const List<_GridItem> _items = [
    _GridItem(Icons.card_giftcard_rounded, 'Refer and Earn'),
    _GridItem(Icons.navigation_rounded, 'Fleet Navigation'),
    _GridItem(Icons.security_rounded, 'Insurance'),
    _GridItem(Icons.map_rounded, 'Offline Map'),
    _GridItem(Icons.local_parking_rounded, 'Parking Orders'),
    _GridItem(Icons.account_balance_wallet_rounded, 'Wallet'),
    _GridItem(Icons.forum_rounded, 'Trucker Forum'),
    _GridItem(Icons.view_list_rounded, 'Free Loadboard'),
    _GridItem(Icons.trending_up_rounded, 'Factoring Service'),
    _GridItem(Icons.document_scanner_rounded, 'Document Scanning'),
    _GridItem(Icons.analytics_rounded, 'Load Market Analysis'),
    _GridItem(Icons.radio_rounded, '10-4 by WEX'),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceLG,
            AppTheme.spaceMD,
            AppTheme.spaceSM,
          ),
          child: Text('Services', style: tt.titleMedium),
        ),
        _buildGrid(context, _items),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, List<_GridItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.05,
        crossAxisSpacing: AppTheme.spaceXS,
        mainAxisSpacing: AppTheme.spaceXS,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _GridCard(item: items[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// More grid (secondary)
// ---------------------------------------------------------------------------

class _MoreSectionGrid extends StatelessWidget {
  const _MoreSectionGrid();

  static const List<_GridItem> _items = [
    _GridItem(Icons.assignment_late_rounded, 'File an Insurance Claim'),
    _GridItem(Icons.store_rounded, 'List My Business'),
    _GridItem(Icons.science_rounded, 'Join App Beta Testers'),
    _GridItem(Icons.flash_on_rounded, 'Northland Quick Claim'),
    _GridItem(Icons.handshake_rounded, 'Partner with Trucker Path'),
    _GridItem(Icons.person_add_rounded, 'Invite Friends'),
    _GridItem(Icons.report_rounded, 'Report Trafficking'),
    _GridItem(Icons.chat_rounded, 'Chat with Us'),
    _GridItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceLG,
            AppTheme.spaceMD,
            AppTheme.spaceSM,
          ),
          child: Text('More', style: tt.titleMedium),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.05,
            crossAxisSpacing: AppTheme.spaceXS,
            mainAxisSpacing: AppTheme.spaceXS,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) => _GridCard(item: _items[index]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared grid card + data class
// ---------------------------------------------------------------------------

class _GridItem {
  const _GridItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.item});

  final _GridItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(AppTheme.spaceXS),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceXS,
            vertical: AppTheme.spaceSM,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 28, color: cs.primary),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                item.label,
                style: tt.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
