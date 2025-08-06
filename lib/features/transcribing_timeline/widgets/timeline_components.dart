import 'package:flutter/material.dart';
import '../utils/timeline_utils.dart';

class TimelineGradient extends StatelessWidget {
  final List<StepData> steps;
  
  const TimelineGradient({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          TimelineStepCard(
            step: steps[i],
            isFirst: i == 0,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class TimelineStepCard extends StatelessWidget {
  final StepData step;
  final bool isFirst;
  final bool isLast;
  
  const TimelineStepCard({
    super.key,
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    // Color scheme - make in-progress and completed cards more consistent
    final Color accent = step.completed ? Color(0xFF1976D2) : Color(0xFF757575); // Blue or darker grey
    final Color borderColor = step.completed ? Color(0xFF1976D2) : Color(0xFF757575); // Consistent with accent
    final Color bgColor = step.completed ? Color(0xFFF4F9FE) : Color(0xFFF5F5F5); // Light blue or light grey

    final bool isSystemThoughts = step.label == 'System Thoughts';
    
    return Padding(
      padding: EdgeInsets.zero, // Remove all gaps between timeline items
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hide timeline indicator for System Thoughts
            if (!isSystemThoughts)
              Container(
                width: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Connecting line from top (for non-first items)
                    if (!isFirst)
                      Positioned(
                        top: 0,
                        height: 9, // Half of the 18px dot position
                        left: 15, // Center the line (32/2 - 1)
                        child: Container(
                          width: 2,
                          color: borderColor.withOpacity(0.8),
                        ),
                      ),
                    // Connecting line to bottom (for non-last items)
                    if (!isLast)
                      Positioned(
                        top: 9, // From center of dot
                        bottom: 0,
                        left: 15, // Center the line (32/2 - 1)
                        child: Container(
                          width: 2,
                          color: borderColor.withOpacity(0.8),
                        ),
                      ),
                    // Dot
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (!isSystemThoughts) const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6), // Consistent margin for all cards
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor.withOpacity(0.18), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14), // Consistent padding for all cards
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              step.label,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF222B45)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (step.duration != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                '(${step.duration!.inSeconds}s)',
                                style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                              ),
                            ),
                          if (step.completed && step.content != null && step.onToggle != null)
                            IconButton(
                              icon: Icon(step.expanded ? Icons.expand_less : Icons.expand_more, color: Color(0xFF90A4AE)),
                              onPressed: step.onToggle,
                              splashRadius: 18,
                            ),
                        ],
                      ),
                      if (step.expanded && (step.content != null || step.customExpandedContent != null))
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor.withOpacity(0.10)),
                          ),
                          child: step.customExpandedContent ?? SelectableText(
                            step.content!,
                            style: const TextStyle(fontSize: 15, color: Color(0xFF222B45)),
                            minLines: 1,
                            maxLines: 8,
                            textAlign: TextAlign.left,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
