import 'package:flutter/material.dart';

class PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isEnabled;
  final VoidCallback onTap;
  final Color activeColor;

  const PermissionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isEnabled,
    required this.onTap,
    this.activeColor = const Color(0xFF00FF9D),
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          Icon(
            icon,
            color: isEnabled ? const Color(0xFF00D4FF) : Colors.white54,
          ),
          if (isEnabled)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Color(0xFF05050A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 12,
                  color: activeColor,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isEnabled ? const Color(0xFF00D4FF) : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
        ),
      ),
      trailing: _buildStatusBadge(),
      onTap: onTap,
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEnabled
            ? activeColor.withOpacity(0.1)
            : const Color(0xFFFF6B6B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isEnabled ? activeColor : const Color(0xFFFF6B6B),
          width: 1,
        ),
      ),
      child: Text(
        isEnabled ? 'ENABLED' : 'DISABLED',
        style: TextStyle(
          color: isEnabled ? activeColor : const Color(0xFFFF6B6B),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
