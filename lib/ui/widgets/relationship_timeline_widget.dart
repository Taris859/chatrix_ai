import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/relationship_chapter.dart';

class RelationshipTimelineWidget extends StatelessWidget {
  final int trustLevel;
  final Color companionThemeColor;

  const RelationshipTimelineWidget({
    Key? key,
    required this.trustLevel,
    required this.companionThemeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeChapter = RelationshipChapter.getChapterForTrust(trustLevel);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "RELATIONSHIP MILESTONES",
          style: GoogleFonts.inter(
            color: Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: RelationshipChapter.chapters.length,
            itemBuilder: (context, index) {
              final chapter = RelationshipChapter.chapters[index];
              final isUnlocked = trustLevel >= chapter.minTrust;
              final isActive = activeChapter.number == chapter.number;
              
              // Define node style based on status
              final Color nodeColor = isActive 
                  ? companionThemeColor 
                  : (isUnlocked ? companionThemeColor.withValues(alpha: 0.6) : Colors.white12);
              
              final double nodeSize = isActive ? 56.0 : 44.0;
              
              return Container(
                width: 140,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Connection Line to the next node
                    if (index < RelationshipChapter.chapters.length - 1)
                      Positioned(
                        top: nodeSize / 2 + (isActive ? 0 : 6),
                        left: 70,
                        right: -70,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                nodeColor,
                                trustLevel >= RelationshipChapter.chapters[index + 1].minTrust
                                    ? companionThemeColor
                                    : Colors.white12,
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // Node content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated Node Container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: nodeSize,
                          height: nodeSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0F1012),
                            border: Border.all(
                              color: nodeColor,
                              width: isActive ? 2.5 : 1.5,
                            ),
                            boxShadow: isActive ? [
                              BoxShadow(
                                color: companionThemeColor.withValues(alpha: 0.35),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ] : null,
                          ),
                          child: Center(
                            child: Text(
                              chapter.icon,
                              style: TextStyle(fontSize: isActive ? 22 : 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Chapter name
                        Text(
                          chapter.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: isActive 
                                ? Colors.white 
                                : (isUnlocked ? Colors.white70 : Colors.white38),
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Unlocks description or lock text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            isUnlocked ? "Unlocked" : "Locked (${chapter.minTrust}%)",
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: isActive 
                                  ? companionThemeColor 
                                  : (isUnlocked ? companionThemeColor.withValues(alpha: 0.7) : Colors.white24),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
