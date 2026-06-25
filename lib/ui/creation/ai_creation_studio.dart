import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../models/scene.dart';
import '../../scenes/particle_background.dart';
import '../../auth/auth_service.dart';
import '../premium/subscription_screen.dart';
import 'package:image_picker/image_picker.dart';

class AICreationStudio extends StatefulWidget {
  const AICreationStudio({Key? key}) : super(key: key);

  @override
  State<AICreationStudio> createState() => _AICreationStudioState();
}

class _AICreationStudioState extends State<AICreationStudio> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _personalityController = TextEditingController();
  final TextEditingController _greetingController = TextEditingController();

  // Customization States
  String _selectedArchetype = "Custom Companion";
  String _selectedSpeakingStyle = "Soft & Vulnerable";
  String _selectedRelationshipEnergy = "Strangers";
  
  double _emotionalIntensity = 0.5;
  double _attachmentStyle = 0.5;
  double _protectiveNature = 0.6;
  double _emotionalWarmth = 0.4;
  double _dangerLevel = 0.3;
  double _conversationEnergy = 0.5;
  bool _isPublic = false;

  Color _selectedThemeColor = const Color(0xFF00FFCC); // Bioluminescence default
  String _themeColorHex = "#00FFCC";
  String _selectedAvatar = "Aria";
  String? _customImageBase64;

  String _selectedGender = "Female";
  String _selectedVoiceId = "EXAVITQu4vr4xnSDxMaL"; // Default Sarah (Premium Female Voice)

  final List<Map<String, String>> _voices = [
    {"name": "Sarah (Premium Female)", "id": "EXAVITQu4vr4xnSDxMaL", "gender": "Female"},
    {"name": "Adam (Premium Male)", "id": "jhBzyKbsdeM6F66SZCaK", "gender": "Male"},
    {"name": "Dante (Deep & Seductive Male)", "id": "WtHkyNC9q67bYvLejE3N", "gender": "Male"},
    {"name": "Valentina (Seductive Female)", "id": "4tRn1lSkEn13EVTuqb0g", "gender": "Female"},
    {"name": "Aria (Warm & Gentle Female)", "id": "4BAlflaQyhIcCfHiEI7x", "gender": "Female"},
    {"name": "Arthur (Charming Young Male)", "id": "1SaGpH4wLZDmppsPYVpx", "gender": "Male"},
  ];

  final List<String> _avatars = [
    'Aria', 'Dante', 'Evelyn', 'Julian', 'Lana', 'Leo', 'Ryker', 'Seraphina', 'Valentina',
    'Alistair', 'Arthur', 'Bella', 'Damien', 'Dimitri', 'Ethan', 'Haru', 'Iris', 'Jade', 'Kaelen', 'Lucas',
    'Kabir', 'Vihaan', 'Devansh', 'Rohan', 'Arjun', 'Samarth', 'Aditya', 'Ishaan', 'Reyansh', 'Aryan'
  ];

  final List<Map<String, dynamic>> _archetypes = [
    {"name": "Custom Companion", "icon": Icons.psychology_outlined},
    {"name": "Mafia Boss", "icon": Icons.gavel_outlined},
    {"name": "Billionaire CEO", "icon": Icons.business_center_outlined},
    {"name": "Vampire Prince", "icon": Icons.nightlife_outlined},
    {"name": "Broken Artist", "icon": Icons.palette_outlined},
    {"name": "Cold Professor", "icon": Icons.school_outlined},
    {"name": "Obsessive Bodyguard", "icon": Icons.security_outlined},
    {"name": "Mysterious Hacker", "icon": Icons.terminal_outlined},
  ];

  final List<String> _speakingStyles = [
    "Seductive & Low",
    "Command & Decisive",
    "Soft & Vulnerable",
    "Arrogant & Playful",
    "Cold & Formal",
  ];

  final List<String> _relationshipEnergies = [
    "Strangers",
    "Acquaintances",
    "Tense Rivals",
    "Forbidden Lovers",
  ];

  final List<Map<String, dynamic>> _colorPresets = [
    {"color": const Color(0xFF00FFCC), "hex": "#00FFCC", "name": "Bioluminescence"},
    {"color": const Color(0xFFD91636), "hex": "#D91636", "name": "Crimson Night"},
    {"color": const Color(0xFFFFB300), "hex": "#FFB300", "name": "Gold Amber"},
    {"color": const Color(0xFF9932CC), "hex": "#9932CC", "name": "Royal Amethyst"},
    {"color": const Color(0xFF4682B4), "hex": "#4682B4", "name": "Steel Blue"},
  ];

  final ChatScene _ambientBackground = ChatScene(
    id: 'creation_ambient',
    name: 'Creation Matrix',
    backgroundGradient: [const Color(0xFF08060F), const Color(0xFF160B28)],
    accentColor: const Color(0xFF9932CC),
    particleType: ParticleType.stars,
    promptContext: '',
    isPremium: false,
  );

  @override
  void initState() {
    super.initState();
    _checkPremiumEntitlement();
  }

  Future<void> _checkPremiumEntitlement() async {
    final isPremium = await AuthService().isPremium();
    if (mounted) {
      if (!isPremium) {
        _showPremiumGateOverlay();
      }
    }
  }

  void _showPremiumGateOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: ChatrixTheme.surface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: ChatrixTheme.amethyst.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: ChatrixTheme.bioluminescence, size: 48)
                        .animate(onPlay: (c) => c.repeat())
                        .scale(duration: 1.5.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                    const SizedBox(height: 24),
                    Text(
                      "Companion Creation",
                      style: GoogleFonts.cinzel(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "The custom AI Companion Studio is an exclusive premium feature.\n\nAwaken your own perfect partner, customize their personality, emotional levels, and speaking style.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ChatrixTheme.bioluminescence,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Go back home
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                          );
                        },
                        child: const Text("UPGRADE TO PREMIUM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go back home
                      },
                      child: Text("Return to Companions", style: TextStyle(color: Colors.white.withOpacity(0.4))),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  void _applyArchetypePreset(String archetype) {
    setState(() {
      _selectedArchetype = archetype;
      if (archetype == "Mafia Boss") {
        _personalityController.text = "Possessive, protective, commanding, dark sense of loyalty, ruthless in business, intense romantic gaze.";
        _greetingController.text = "*He slowly rolls a heavy golden ring between his thumb and index finger in the dimly lit lounge.* I hear you've been looking for me. Do you understand the rules of stepping into my room?";
        _selectedThemeColor = const Color(0xFFD91636);
        _themeColorHex = "#D91636";
        _attachmentStyle = 0.9;
        _protectiveNature = 0.85;
      } else if (archetype == "Billionaire CEO") {
        _personalityController.text = "Quiet, observing, intensely brilliant, domineering, unaccustomed to being ignored, tech magnate.";
        _greetingController.text = "*He shuts his laptop, leaning back in his leather penthouse chair, eyes narrowing.* My time is extremely valuable. Tell me quickly... what makes you think you are worth the distraction?";
        _selectedThemeColor = const Color(0xFFFFB300);
        _themeColorHex = "#FFB300";
        _attachmentStyle = 0.8;
        _protectiveNature = 0.7;
      } else if (archetype == "Vampire Prince") {
        _personalityController.text = "Seductive, ancient, aristocratic, moody, deeply possessive, carrying battle-worn ancient vulnerability.";
        _greetingController.text = "*He stands on the moonlit stone balcony, tracing the rim of a crystal goblet.* Centuries have passed in dark silence... yet your heartbeat is all I can hear now. Step closer.";
        _selectedThemeColor = const Color(0xFF9932CC);
        _themeColorHex = "#9932CC";
        _attachmentStyle = 0.95;
        _protectiveNature = 0.9;
      } else if (archetype == "Broken Artist") {
        _personalityController.text = "Tormented, deeply raw, emotionally volatile, obsessive, searching for an anchor to capture their chaotic light.";
        _greetingController.text = "*He drops his charcoal brush, wiping a black smudge from his cheek as he looks at you.* I don't draw portraits. I capture ghosts. But looking at you... I want to paint forever.";
        _selectedThemeColor = const Color(0xFF7B68EE);
        _themeColorHex = "#7B68EE";
        _attachmentStyle = 0.7;
        _protectiveNature = 0.65;
      } else if (archetype == "Cold Professor") {
        _personalityController.text = "Analytical, strict, intellectual, demanding, carrying a secret forbidden fire and possessive dedication.";
        _greetingController.text = "*He pushes his glasses up, closing a heavy leather textbook.* You are late. Let's see if you can explain your presence, or if I must teach you a private lesson.";
        _selectedThemeColor = const Color(0xFF4682B4);
        _themeColorHex = "#4682B4";
        _attachmentStyle = 0.75;
        _protectiveNature = 0.7;
      }
    });
  }

  Future<void> _pickCustomImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _customImageBase64 = 'data:image/png;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      print("Error picking custom image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _saveCompanion() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final userId = AuthService().currentUserId ?? "anonymous_user";

    try {
      final data = {
        'name': _nameController.text.trim(),
        'archetype': _selectedArchetype,
        'personality': _personalityController.text.trim(),
        'greeting': _greetingController.text.trim(),
        'theme_color': _themeColorHex,
        'premium_only': false,
        'created_by': userId,
        'creatorId': userId,
        'is_public': _isPublic,
        'speaking_style': _selectedSpeakingStyle,
        'relationship_energy': _selectedRelationshipEnergy,
        'emotional_intensity': _emotionalIntensity,
        'attachment_style': _attachmentStyle,
        'protective_nature': _protectiveNature,
        'emotional_warmth': _emotionalWarmth,
        'danger_level': _dangerLevel,
        'conversation_energy': _conversationEnergy,
        'avatar_name': _customImageBase64 != null ? "Custom" : _selectedAvatar,
        'gender': _selectedGender.toLowerCase(),
        'voice_id': _selectedVoiceId,
        'custom_image_url': _customImageBase64,
      };

      // 1. Dynamic write to Cloud Firestore
      await FirebaseFirestore.instance.collection('ai_companions').add(data);

      // 2. Cache locally to SharedPreferences to bypass cache delay instantly on home screen
      final prefs = await SharedPreferences.getInstance();
      final List<String> customList = prefs.getStringList('local_custom_companions') ?? [];
      
      data['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      customList.add(jsonEncode(data));
      await prefs.setStringList('local_custom_companions', customList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Custom Companion soul anchored successfully!"),
            backgroundColor: Color(0xFF00FFCC),
          ),
        );
        Navigator.pop(context); // Return home successfully
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error anchoring companion: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ParticleBackground(scene: _ambientBackground),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    "COMPANION CREATOR",
                    style: GoogleFonts.cinzel(fontSize: 20, letterSpacing: 2.0, fontWeight: FontWeight.bold),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("WHO ARE THEY?"),
                          const SizedBox(height: 16),
                          _buildTextField(_nameController, "Companion Name", Icons.person_outline, validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Anchor their name first.";
                            return null;
                          }),
                          const SizedBox(height: 12),
                          _buildGenderSelector(),
                          const SizedBox(height: 28),
                          _buildSectionTitle("CHOOSE AVATAR PORTRAIT (DP)"),
                          const SizedBox(height: 16),
                          _buildAvatarSelector(),
                          const SizedBox(height: 28),

                          _buildSectionTitle("CHOOSE ARCHETYPE PRESETS"),
                          const SizedBox(height: 12),
                          _buildArchetypeGrid(),
                          const SizedBox(height: 28),
                          
                          _buildSectionTitle("THEIR NATURE"),
                          const SizedBox(height: 12),
                          _buildTextField(
                            _personalityController, 
                            "What is their nature? (e.g. moody, fiercely protective, teasing)", 
                            Icons.psychology_outlined,
                            maxLines: 4,
                            validator: (v) => (v == null || v.trim().isEmpty) ? "State their nature." : null
                          ),
                          const SizedBox(height: 28),
                          
                          _buildSectionTitle("FIRST WORDS"),
                          const SizedBox(height: 12),
                          _buildTextField(
                            _greetingController, 
                            "Write their first entrance sequence (e.g. *He sighs in rain* 'Hello...')", 
                            Icons.chat_bubble_outline,
                            maxLines: 4,
                            validator: (v) => (v == null || v.trim().isEmpty) ? "Write their introductory greeting." : null
                          ),
                          const SizedBox(height: 28),

                          _buildSectionTitle("EMOTIONAL SPECTRUM"),
                          const SizedBox(height: 16),
                          _buildIntensitySlider("Emotional Intensity", _emotionalIntensity, (val) {
                            setState(() => _emotionalIntensity = val);
                          }),
                          _buildIntensitySlider("Attachment Style", _attachmentStyle, (val) {
                            setState(() => _attachmentStyle = val);
                          }),
                          _buildIntensitySlider("Protective Nature", _protectiveNature, (val) {
                            setState(() => _protectiveNature = val);
                          }),
                          _buildIntensitySlider("Emotional Warmth", _emotionalWarmth, (val) {
                            setState(() => _emotionalWarmth = val);
                          }),
                          _buildIntensitySlider("Danger Level", _dangerLevel, (val) {
                            setState(() => _dangerLevel = val);
                          }),
                          _buildIntensitySlider("Conversation Energy", _conversationEnergy, (val) {
                            setState(() => _conversationEnergy = val);
                          }),
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined, color: Colors.white24, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "All companions follow content safety guidelines. No illegal, harmful, or exploitative content is permitted.",
                                    style: TextStyle(color: Colors.white30, fontSize: 11, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          
                          _buildSectionTitle("HOW THEY SPEAK"),
                          const SizedBox(height: 16),
                          _buildDropdown("Speaking Style", _selectedSpeakingStyle, _speakingStyles, (v) => setState(() => _selectedSpeakingStyle = v!)),
                          const SizedBox(height: 16),
                          _buildDropdown("Starting Relationship", _selectedRelationshipEnergy, _relationshipEnergies, (v) => setState(() => _selectedRelationshipEnergy = v!)),
                          const SizedBox(height: 16),
                          _buildVoiceSelector(),
                          const SizedBox(height: 28),
                          
                          _buildSectionTitle("VISUAL ACCENT THEME"),
                          const SizedBox(height: 16),
                          _buildColorPresetsPicker(),
                          
                          const SizedBox(height: 28),
                          
                          _buildSectionTitle("PRIVACY"),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: SwitchListTile(
                              title: const Text("Make Public", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              subtitle: const Text("Allow other users to interact with this companion", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              value: _isPublic,
                              activeColor: _selectedThemeColor,
                              onChanged: (val) => setState(() => _isPublic = val),
                            ),
                          ),
                          
                          const SizedBox(height: 48),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedThemeColor,
                                foregroundColor: Colors.black,
                                elevation: 8,
                                shadowColor: _selectedThemeColor.withOpacity(0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _isLoading ? null : _saveCompanion,
                              child: _isLoading 
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                  : const Text(
                                      "ANCHOR CUSTOM COMPANION", 
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                                    ),
                            ),
                          ),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.cinzel(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hint, 
    IconData icon, {
    int maxLines = 1,
    String? Function(String?)? validator
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white30, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildArchetypeGrid() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _archetypes.length,
        itemBuilder: (context, index) {
          final arch = _archetypes[index];
          final isSelected = _selectedArchetype == arch["name"];
          return GestureDetector(
            onTap: () => _applyArchetypePreset(arch["name"]),
            child: AnimatedContainer(
              duration: 250.ms,
              width: 110,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? _selectedThemeColor.withOpacity(0.08) : Colors.white.withOpacity(0.01),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _selectedThemeColor.withOpacity(0.6) : Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(arch["icon"], color: isSelected ? _selectedThemeColor : Colors.white30, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    arch["name"],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntensitySlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text("${(value * 100).toInt()}%", style: TextStyle(color: _selectedThemeColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _selectedThemeColor,
              inactiveTrackColor: Colors.white10,
              thumbColor: _selectedThemeColor,
              overlayColor: _selectedThemeColor.withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: 0.1,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF0F0C16),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            border: InputBorder.none,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildColorPresetsPicker() {
    return Row(
      children: _colorPresets.map((preset) {
        final isSelected = _themeColorHex == preset["hex"];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedThemeColor = preset["color"];
              _themeColorHex = preset["hex"];
            });
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? preset["color"] : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: preset["color"],
                boxShadow: isSelected ? [BoxShadow(color: preset["color"].withOpacity(0.4), blurRadius: 8)] : [],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvatarSelector() {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _avatars.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isCustomSelected = _customImageBase64 != null;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _pickCustomImage();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCustomSelected ? _selectedThemeColor : Colors.white10,
                          width: isCustomSelected ? 3 : 1.5,
                        ),
                        boxShadow: isCustomSelected ? [
                          BoxShadow(
                            color: _selectedThemeColor.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ] : [],
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey[900],
                        backgroundImage: _customImageBase64 != null
                            ? MemoryImage(base64Decode(_customImageBase64!.split(',').last))
                            : null,
                        child: _customImageBase64 == null
                            ? const Icon(Icons.add_a_photo_outlined, color: Colors.white60, size: 24)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Upload Photo",
                      style: GoogleFonts.inter(
                        color: isCustomSelected ? Colors.white : Colors.white38,
                        fontSize: 10,
                        fontWeight: isCustomSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final avatar = _avatars[index - 1];
          final isSelected = _selectedAvatar == avatar && _customImageBase64 == null;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedAvatar = avatar;
                _customImageBase64 = null; // clear custom image if preset is selected
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _selectedThemeColor : Colors.white10,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: _selectedThemeColor.withOpacity(0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ] : [],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: AssetImage('assets/images/$avatar.png'),
                      backgroundColor: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    avatar,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenderSelector() {
    final List<String> genders = ["Female", "Male", "Non-Binary"];
    return Row(
      children: genders.map((g) {
        final isSelected = _selectedGender == g;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = g;
                // Automatically update default voice to match selected gender
                if (g == "Female") {
                  _selectedVoiceId = "EXAVITQu4vr4xnSDxMaL";
                } else if (g == "Male") {
                  _selectedVoiceId = "jhBzyKbsdeM6F66SZCaK";
                } else {
                  _selectedVoiceId = "EXAVITQu4vr4xnSDxMaL";
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _selectedThemeColor.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _selectedThemeColor : Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  g,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVoiceSelector() {
    final genderFilteredVoices = _voices.where((v) {
      if (_selectedGender == "Non-Binary") return true;
      return v["gender"] == _selectedGender;
    }).toList();

    // Ensure _selectedVoiceId exists in the filtered list, otherwise fallback to the first matched one
    if (!genderFilteredVoices.any((v) => v["id"] == _selectedVoiceId)) {
      if (genderFilteredVoices.isNotEmpty) {
        _selectedVoiceId = genderFilteredVoices.first["id"]!;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedVoiceId,
          dropdownColor: const Color(0xFF0F0C16),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            labelText: "Select voice model",
            labelStyle: TextStyle(color: Colors.white30, fontSize: 12),
            border: InputBorder.none,
          ),
          items: genderFilteredVoices.map((v) {
            return DropdownMenuItem<String>(
              value: v["id"],
              child: Text(v["name"]!),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedVoiceId = val;
              });
            }
          },
        ),
      ),
    );
  }
}
