import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import '../../theme/app_theme.dart';

class CareTipsScreen extends StatefulWidget {
  const CareTipsScreen({super.key});

  @override
  State<CareTipsScreen> createState() => _CareTipsScreenState();
}

class _CareTipsScreenState extends State<CareTipsScreen> {
  String _selectedCategory = 'All';

  static const _categories = ['All', 'Posture', 'Sleeping', 'Exercise', 'Diet', 'Recovery'];

  static const _tips = [
    _Tip(title: 'Sit with a Straight Back', category: 'Posture', icon: Icons.chair_rounded, color: Color(0xFF0A6BE8), body: 'Keep your back straight and feet flat on the floor when sitting. Avoid slouching or leaning forward for extended periods. Use a lumbar support cushion if needed.'),
    _Tip(title: 'Take Standing Breaks', category: 'Posture', icon: Icons.accessibility_new_rounded, color: Color(0xFF6366F1), body: 'Stand up and stretch every 30–45 minutes if you work at a desk. This reduces pressure on the spine and improves circulation. Set a timer as a reminder.'),
    _Tip(title: 'Screen at Eye Level', category: 'Posture', icon: Icons.monitor_rounded, color: Color(0xFF8B5CF6), body: 'Position your computer screen at eye level to prevent neck strain. The top of the monitor should align with your eye height. Use a stand or stack if needed.'),
    _Tip(title: 'Sleep on Your Side', category: 'Sleeping', icon: Icons.bed_rounded, color: Color(0xFF00A86B), body: 'Sleeping on your side with a pillow between your knees is best for spinal alignment. Avoid sleeping on your stomach as it strains the neck. Use a supportive pillow.'),
    _Tip(title: 'Choose the Right Pillow', category: 'Sleeping', icon: Icons.king_bed_rounded, color: Color(0xFFF59E0B), body: 'Use a pillow that keeps your neck aligned with your spine. Too high or too flat pillows cause neck pain. Consider an orthopedic pillow for better support.'),
    _Tip(title: 'Firm Mattress Matters', category: 'Sleeping', icon: Icons.hotel_rounded, color: Color(0xFF10B981), body: 'A medium-firm mattress is recommended for spinal health. Mattresses that sag can worsen back pain. Replace your mattress every 7–10 years.'),
    _Tip(title: 'Core Strengthening', category: 'Exercise', icon: Icons.fitness_center_rounded, color: Color(0xFFEF4444), body: 'Strengthening your core muscles supports the spine and reduces back pain. Exercises like planks, bridges, and bird-dogs are highly effective. Aim for 3 sessions per week.'),
    _Tip(title: 'Daily Stretching', category: 'Exercise', icon: Icons.self_improvement_rounded, color: Color(0xFF0A6BE8), body: 'Gentle stretching each morning helps maintain spinal flexibility. Focus on hamstrings, hip flexors, and upper back. Hold each stretch for 20–30 seconds.'),
    _Tip(title: 'Walk 30 Minutes Daily', category: 'Exercise', icon: Icons.directions_walk_rounded, color: Color(0xFF00C9A7), body: 'A daily 30-minute walk keeps the spine healthy and reduces stiffness. Walking with proper posture — head up, shoulders back — is essential. Use supportive shoes.'),
    _Tip(title: 'Stay Hydrated', category: 'Diet', icon: Icons.water_drop_rounded, color: Color(0xFF3B82F6), body: 'Spinal discs need water to maintain height and shock-absorbing ability. Drink at least 8 glasses of water daily. Dehydration can worsen disc problems.'),
    _Tip(title: 'Anti-Inflammatory Foods', category: 'Diet', icon: Icons.restaurant_rounded, color: Color(0xFF22C55E), body: 'Eat foods rich in omega-3 fatty acids like salmon, walnuts, and flaxseed. These reduce inflammation in joints and muscles. Avoid processed foods and excess sugar.'),
    _Tip(title: 'Calcium and Vitamin D', category: 'Diet', icon: Icons.egg_rounded, color: Color(0xFFEAB308), body: 'Calcium and Vitamin D are essential for strong bones and spine. Get calcium from dairy, leafy greens, and almonds. Get Vitamin D from sunlight and fortified foods.'),
    _Tip(title: 'Ice Before Heat', category: 'Recovery', icon: Icons.ac_unit_rounded, color: Color(0xFF60A5FA), body: 'For acute pain (first 48 hours), use ice to reduce inflammation. Apply ice for 15–20 minutes at a time. After 48 hours, switch to heat for muscle relaxation.'),
    _Tip(title: 'Follow Your Care Plan', category: 'Recovery', icon: Icons.health_and_safety_rounded, color: Color(0xFF8B5CF6), body: 'Complete all recommended visits even when pain improves. Early discontinuation often leads to recurrence. Communicate any concerns with DR. BASHIR AHMAD.'),
    _Tip(title: 'Avoid Heavy Lifting', category: 'Recovery', icon: Icons.warning_rounded, color: Color(0xFFF59E0B), body: 'During recovery, avoid lifting heavy objects. If lifting is necessary, bend at the knees — not the waist — and keep the load close to your body. Never twist while lifting.'),
  ];

  List<_Tip> get _filtered => _selectedCategory == 'All' ? _tips : _tips.where((t) => t.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 750;

    final leftColumnItems = <_Tip>[];
    final rightColumnItems = <_Tip>[];
    for (var i = 0; i < _filtered.length; i++) {
      if (i % 2 == 0) {
        leftColumnItems.add(_filtered[i]);
      } else {
        rightColumnItems.add(_filtered[i]);
      }
    }

    return AppShellScaffold(
      title: 'Care Tips',
      currentRoute: '/care-tips',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : cs.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Text(cat, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : cs.onSurface.withValues(alpha: 0.7))),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          isWide
              ? Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: leftColumnItems.map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TipCard(tip: tip),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: rightColumnItems.map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TipCard(tip: tip),
                            )).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TipCard(tip: _filtered[i]),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _Tip {
  const _Tip({required this.title, required this.category, required this.icon, required this.color, required this.body});
  final String title, category, body;
  final IconData icon;
  final Color color;
}

class _TipCard extends StatefulWidget {
  const _TipCard({required this.tip});
  final _Tip tip;

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = widget.tip;

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(t.icon, color: t.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: t.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(t.category, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: t.color)),
                  ),
                ])),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Divider(),
                          const SizedBox(height: 10),
                          Text(t.body, style: GoogleFonts.poppins(fontSize: 13, height: 1.6, color: cs.onSurface.withValues(alpha: 0.75))),
                        ]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
