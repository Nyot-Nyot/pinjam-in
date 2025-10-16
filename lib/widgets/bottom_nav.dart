import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  Alignment _alignForIndex(int i) {
    return i == 0
        ? const Alignment(-1.0, 0)
        : i == 1
        ? const Alignment(0.0, 0)
        : const Alignment(1.0, 0);
  }

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 360);
    final align = _alignForIndex(selectedIndex);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEBE1F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.12),
            offset: Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: Color(0xFFE6DBF8), height: 1),
          Padding(
            padding: const EdgeInsets.only(
              top: 12.0,
              left: 20.0,
              right: 20.0,
              bottom: 12.0,
            ),
            child: SizedBox(
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedAlign(
                    alignment: align,
                    duration: duration,
                    curve: Curves.easeInOut,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8530E4),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => onTap(0),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(
                            child: Icon(
                              Icons.home,
                              color: selectedIndex == 0
                                  ? Colors.white
                                  : const Color(0xFF0C0315),
                              size: 26.4,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onTap(1),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(
                            child: Icon(
                              Icons.add,
                              color: selectedIndex == 1
                                  ? Colors.white
                                  : const Color(0xFF0C0315),
                              size: 24.0,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onTap(2),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(
                            child: Icon(
                              Icons.history,
                              color: selectedIndex == 2
                                  ? Colors.white
                                  : const Color(0xFF0C0315),
                              size: 24.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
