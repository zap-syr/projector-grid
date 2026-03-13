import 'package:flutter/material.dart';

class ControlBar extends StatelessWidget {
  const ControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Control Panel',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _ControlButton(
                  label: 'Power On',
                  icon: Icons.power,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                _ControlButton(
                  label: 'Power Standby',
                  icon: Icons.power_off,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                _ControlButton(
                  label: 'Switch Input',
                  icon: Icons.input,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                _ControlButton(
                  label: 'Shutter On',
                  icon: Icons.visibility_off,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                _ControlButton(
                  label: 'Shutter Off',
                  icon: Icons.visibility,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
