import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../theme/clovara_theme.dart';
import '../ai/ai_service.dart';
import '../models/owner.dart';
import '../models/pet.dart';
import '../services/risk_scoring_engine.dart';
import '../services/marketing_attribution_service.dart';
import 'medical_underwriting_screen.dart';

/// Quote flow screen for getting insurance quotes
class QuoteFlowScreen extends StatefulWidget {
  const QuoteFlowScreen({super.key});

  @override
  State<QuoteFlowScreen> createState() => _QuoteFlowScreenState();
}

class _QuoteFlowScreenState extends State<QuoteFlowScreen> {
  static const int _totalSteps = 4;

  int _currentStep = 0;

  bool _isSubmitting = false;

  final Map<String, dynamic> _formData = {'species': null, 'dateOfBirth': null};

  final _petFormKey = GlobalKey<FormState>();
  final _ownerFormKey = GlobalKey<FormState>();
  final _medicalFormKey = GlobalKey<FormState>();

  late final TextEditingController _petNameController;
  late final TextEditingController _breedController;
  late final TextEditingController _dobController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipController;
  late final TextEditingController _conditionsController;

  @override
  void initState() {
    super.initState();

    // Best-effort marketing attribution
    MarketingAttributionService().trackQuoteStartedOnce();

    _petNameController = TextEditingController();
    _breedController = TextEditingController();
    _dobController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _stateController = TextEditingController();
    _zipController = TextEditingController();
    _conditionsController = TextEditingController();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      _emailController.text = currentUser.email!;
      _formData['email'] = currentUser.email;
    }
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _breedController.dispose();
    _dobController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepMeta = _stepMeta(_currentStep);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get a Quote'),
        actions: [_buildAccountAction(context), const SizedBox(width: 8)],
      ),
      body: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            Column(
              children: [
                _buildProgressHeader(
                  title: stepMeta.title,
                  subtitle: stepMeta.subtitle,
                  progress: (_currentStep + 1) / _totalSteps,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Padding(
                      key: ValueKey(_currentStep),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildStepBody(_currentStep),
                    ),
                  ),
                ),
                _buildBottomBar(context),
              ],
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Generating your plans...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountAction(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return PopupMenuButton<String>(
            icon: Icon(Icons.account_circle, color: ClovaraColors.forest),
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'dashboard') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CustomerHomeScreen(isPremium: false),
                  ),
                );
              } else if (value == 'logout') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dashboard',
                child: Row(
                  children: [
                    const Icon(Icons.dashboard, size: 20),
                    const SizedBox(width: 8),
                    Text(snapshot.data?.email ?? 'My Account'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          );
        }

        return TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          icon: Icon(Icons.login, color: ClovaraColors.forest),
          label: Text('Login', style: TextStyle(color: ClovaraColors.forest)),
        );
      },
    );
  }

  Widget _buildProgressHeader({
    required String title,
    required String subtitle,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: ClovaraColors.white,
        border: Border(bottom: BorderSide(color: ClovaraColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ClovaraTypography.h3),
                    const SizedBox(height: 4),
                    Text(subtitle, style: ClovaraTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/conversational-quote'),
                child: const Text('Chat instead'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentStep + 1}/$_totalSteps',
                style: ClovaraTypography.bodySmall.copyWith(
                  color: ClovaraColors.slate.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return _buildPetStep();
      case 1:
        return _buildOwnerStep();
      case 2:
        return _buildHealthStep();
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPetStep() {
    return Form(
      key: _petFormKey,
      child: ListView(
        children: [
          _StepCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let\'s start with the basics.',
                  style: ClovaraTypography.body,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _petNameController,
                  decoration: const InputDecoration(labelText: 'Pet name'),
                  textInputAction: TextInputAction.next,
                  onChanged: (value) => _formData['petName'] = value.trim(),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty)
                      return 'Please enter your pet\'s name.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text('Species', style: ClovaraTypography.label),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'Dog',
                      label: Text('Dog'),
                      icon: Icon(Icons.pets),
                    ),
                    ButtonSegment<String>(
                      value: 'Cat',
                      label: Text('Cat'),
                      icon: Icon(Icons.pets),
                    ),
                  ],
                  selected: {
                    if (_formData['species'] != null)
                      _formData['species'] as String,
                  },
                  onSelectionChanged: (values) {
                    setState(() {
                      _formData['species'] = values.first;
                    });
                  },
                ),
                if (_formData['species'] == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Please select Dog or Cat.',
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: ClovaraColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _breedController,
                  decoration: const InputDecoration(
                    labelText: 'Breed',
                    hintText: 'e.g., Golden Retriever, Domestic Shorthair',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (value) => _formData['breed'] = value.trim(),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Please enter a breed.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildDobField(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoStrip(
            icon: Icons.lock,
            title: 'Privacy-first',
            body: 'We use this info only to price the quote. No spam.',
          ),
        ],
      ),
    );
  }

  Widget _buildDobField() {
    final date = _formData['dateOfBirth'] as DateTime?;
    _dobController.text = date == null
        ? ''
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final initial = date ?? DateTime(now.year - 2, now.month, now.day);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial.isAfter(now) ? now : initial,
          firstDate: DateTime(2000),
          lastDate: now,
        );
        if (picked != null) {
          setState(() {
            _formData['dateOfBirth'] = picked;
            _dobController.text =
                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          });
        }
      },
      child: IgnorePointer(
        child: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Birthday',
            hintText: 'Select a date',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          controller: _dobController,
          validator: (_) {
            final date = _formData['dateOfBirth'] as DateTime?;
            if (date == null) return 'Please select a birthday.';
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildOwnerStep() {
    return Form(
      key: _ownerFormKey,
      child: ListView(
        children: [
          _StepCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where should we send your quote?',
                  style: ClovaraTypography.body,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (value) =>
                            _formData['firstName'] = value.trim(),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (value) =>
                            _formData['lastName'] = value.trim(),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (value) => _formData['email'] = value.trim(),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Please enter your email.';
                    final emailOk = RegExp(r'^.+@.+\..+$').hasMatch(trimmed);
                    if (!emailOk) return 'Please enter a valid email.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    hintText: 'For updates if you choose SMS',
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) => _formData['phone'] = value.trim(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          hintText: 'e.g., CA',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (value) {
                          final upper = value.toUpperCase();
                          if (upper != value) {
                            _stateController.value = _stateController.value
                                .copyWith(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                    offset: upper.length,
                                  ),
                                );
                          }
                          _formData['state'] = upper.trim();
                        },
                        validator: (value) {
                          final trimmed = (value ?? '').trim();
                          if (trimmed.isEmpty) return 'Required';
                          if (trimmed.length != 2) return 'Use 2-letter code';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _zipController,
                        decoration: const InputDecoration(
                          labelText: 'ZIP code',
                          hintText: 'e.g., 94107',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) =>
                            _formData['zipCode'] = value.trim(),
                        validator: (value) {
                          final trimmed = (value ?? '').trim();
                          if (trimmed.isEmpty) return 'Required';
                          final ok = RegExp(
                            r'^\d{5}(-\d{4})?$',
                          ).hasMatch(trimmed);
                          if (!ok) return 'Invalid ZIP';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoStrip(
            icon: Icons.schedule,
            title: 'Takes about 2 minutes',
            body: 'You can review everything before submitting.',
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStep() {
    return Form(
      key: _medicalFormKey,
      child: ListView(
        children: [
          _StepCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Optional, but helpful.', style: ClovaraTypography.body),
                const SizedBox(height: 16),
                Text('Veterinary records', style: ClovaraTypography.label),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Upload coming soon.')),
                    );
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload records (optional)'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Known conditions (optional)',
                  style: ClovaraTypography.label,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _conditionsController,
                  decoration: const InputDecoration(
                    labelText: 'Conditions',
                    hintText: 'e.g., allergies, arthritis, diabetes',
                  ),
                  maxLines: 3,
                  onChanged: (value) => _formData['conditions'] = value.trim(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoStrip(
            icon: Icons.info,
            title: 'Why we ask',
            body: 'This helps avoid surprises later. You can leave it blank.',
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final petName = (_formData['petName'] ?? '').toString();
    final species = (_formData['species'] ?? 'N/A').toString();
    final breed = (_formData['breed'] ?? '').toString();
    final dob = _formData['dateOfBirth'] as DateTime?;
    final dobText = dob == null
        ? 'N/A'
        : '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';

    final ownerName =
        '${(_formData['firstName'] ?? '').toString()} ${(_formData['lastName'] ?? '').toString()}'
            .trim();
    final email = (_formData['email'] ?? '').toString();
    final phone = (_formData['phone'] ?? '').toString();
    final state = (_formData['state'] ?? '').toString();
    final zip = (_formData['zipCode'] ?? '').toString();
    final conditions = (_formData['conditions'] ?? '').toString();

    return ListView(
      children: [
        _StepCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review', style: ClovaraTypography.h3),
              const SizedBox(height: 8),
              Text(
                'Make sure everything looks right.',
                style: ClovaraTypography.bodySmall,
              ),
              const SizedBox(height: 18),
              _ReviewSection(
                title: 'Pet',
                onEdit: () => setState(() => _currentStep = 0),
                rows: [
                  _ReviewRow(
                    label: 'Name',
                    value: petName.isEmpty ? 'N/A' : petName,
                  ),
                  _ReviewRow(label: 'Species', value: species),
                  _ReviewRow(
                    label: 'Breed',
                    value: breed.isEmpty ? 'N/A' : breed,
                  ),
                  _ReviewRow(label: 'Birthday', value: dobText),
                ],
              ),
              const SizedBox(height: 14),
              _ReviewSection(
                title: 'Owner',
                onEdit: () => setState(() => _currentStep = 1),
                rows: [
                  _ReviewRow(
                    label: 'Name',
                    value: ownerName.isEmpty ? 'N/A' : ownerName,
                  ),
                  _ReviewRow(
                    label: 'Email',
                    value: email.isEmpty ? 'N/A' : email,
                  ),
                  _ReviewRow(
                    label: 'Phone',
                    value: phone.isEmpty ? '—' : phone,
                  ),
                  _ReviewRow(
                    label: 'Location',
                    value: (state.isEmpty || zip.isEmpty)
                        ? 'N/A'
                        : '$state $zip',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ReviewSection(
                title: 'Health',
                onEdit: () => setState(() => _currentStep = 2),
                rows: [
                  _ReviewRow(
                    label: 'Conditions',
                    value: conditions.isEmpty ? '—' : conditions,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoStrip(
          icon: Icons.favorite,
          title: 'Next: choose a plan',
          body: 'We\'ll show coverage options and pricing.',
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isLast = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: ClovaraColors.white,
        border: Border(top: BorderSide(color: ClovaraColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _currentStep == 0 ? null : _onBack,
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (isLast ? _submitQuote : _onContinue),
              child: Text(isLast ? 'See Plans' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  void _onBack() {
    if (_currentStep == 0) return;
    setState(() => _currentStep--);
  }

  void _onContinue() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      final speciesOk = _formData['species'] != null;
      final petOk = _petFormKey.currentState?.validate() ?? false;
      if (!speciesOk) {
        setState(() {});
      }
      return petOk && speciesOk;
    }

    if (_currentStep == 1) {
      return _ownerFormKey.currentState?.validate() ?? false;
    }

    if (_currentStep == 2) {
      return _medicalFormKey.currentState?.validate() ?? true;
    }

    return true;
  }

  _StepMeta _stepMeta(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return const _StepMeta(
          title: 'About your pet',
          subtitle: 'A few details to personalize pricing.',
        );
      case 1:
        return const _StepMeta(
          title: 'About you',
          subtitle: 'Where should we send your quote?',
        );
      case 2:
        return const _StepMeta(
          title: 'Health (optional)',
          subtitle: 'Helps reduce surprises later.',
        );
      case 3:
        return const _StepMeta(
          title: 'Review',
          subtitle: 'Confirm everything before plans.',
        );
      default:
        return const _StepMeta(title: 'Quote', subtitle: '');
    }
  }

  Future<void> _submitQuote() async {
    if (_isSubmitting) return;

    // Re-validate key steps (defensive) and bounce the user to the first invalid step.
    if (!_validateAllStepsAndJump()) return;

    // Ensure latest controller values are captured.
    _formData['petName'] = _petNameController.text.trim();
    _formData['breed'] = _breedController.text.trim();
    _formData['firstName'] = _firstNameController.text.trim();
    _formData['lastName'] = _lastNameController.text.trim();
    _formData['email'] = _emailController.text.trim();
    _formData['phone'] = _phoneController.text.trim();
    _formData['state'] = _stateController.text.trim().toUpperCase();
    _formData['zipCode'] = _zipController.text.trim();
    _formData['conditions'] = _conditionsController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final pet = _createPetFromForm();
      final owner = _createOwnerFromForm();

      final aiService = GPTService();
      final riskEngine = RiskScoringEngine(aiService: aiService);

      final result = await riskEngine.calculateRiskScoreWithEligibility(
        pet: pet,
        owner: owner,
      );

      final bool isComplexCase =
          pet.preExistingConditions.isNotEmpty || result.hasExclusions;

      if (!result.isEligible && mounted) {
        await _showDeclineDialog(
          petName: pet.name,
          reason:
              result.rejectionReason ??
              'This application does not meet our current underwriting guidelines.',
        );
        return;
      }

      if (isComplexCase && mounted) {
        // Ask any extra medical underwriting questions *before* plan selection.
        // This does not require sign-in; auth is enforced at checkout.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MedicalUnderwritingScreen(
              pet: pet,
              riskScore: result.riskScore,
              quoteData: {
                ..._formData,
                'petData': _formData,
                'pet': pet,
                'owner': owner,
                'riskScore': result.riskScore,
                'needsMedicalUnderwriting': true,
                'hasExclusions': result.hasExclusions,
                'excludedConditions': result.excludedConditions,
              },
            ),
          ),
        );
        return;
      }

      // Eligible, non-complex: show plan selection with dynamic plans.
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/plan-selection',
        arguments: {
          ..._formData,
          'petData': _formData,
          'pet': pet,
          'owner': owner,
          'riskScore': result.riskScore,
        },
      );
    } catch (e) {
      // Fall back to plans even if AI/risk fails.
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/plan-selection',
        arguments: {..._formData, 'petData': _formData, 'riskScore': null},
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _validateAllStepsAndJump() {
    // Pet step
    final petSpeciesOk = _formData['species'] != null;
    final petOk = _petFormKey.currentState?.validate() ?? false;
    if (!petOk || !petSpeciesOk) {
      setState(() => _currentStep = 0);
      if (!petSpeciesOk) setState(() {});
      return false;
    }

    // Owner step
    final ownerOk = _ownerFormKey.currentState?.validate() ?? false;
    if (!ownerOk) {
      setState(() => _currentStep = 1);
      return false;
    }

    return true;
  }

  Pet _createPetFromForm() {
    final petName = (_formData['petName'] ?? '').toString().trim();
    final breed = (_formData['breed'] ?? '').toString().trim();
    final species = (_formData['species'] ?? 'Dog').toString().toLowerCase();
    final dob = _formData['dateOfBirth'] as DateTime?;
    final conditionsText = (_formData['conditions'] ?? '').toString();
    final preExisting = _parseConditionsList(conditionsText);

    return Pet(
      id: 'pet_${DateTime.now().millisecondsSinceEpoch}',
      name: petName.isEmpty ? 'Pet' : petName,
      species: species,
      breed: breed.isEmpty ? 'Mixed Breed' : breed,
      dateOfBirth:
          dob ?? DateTime.now().subtract(const Duration(days: 365 * 2)),
      gender: 'unknown',
      weight: 10.0,
      isNeutered: false,
      preExistingConditions: preExisting,
      isReceivingTreatment: null,
    );
  }

  Owner _createOwnerFromForm() {
    final firstName = (_formData['firstName'] ?? '').toString().trim();
    final lastName = (_formData['lastName'] ?? '').toString().trim();
    final email = (_formData['email'] ?? '').toString().trim();
    final phone = (_formData['phone'] ?? '').toString().trim();
    final state = (_formData['state'] ?? '').toString().trim().toUpperCase();
    final zip = (_formData['zipCode'] ?? '').toString().trim();

    return Owner(
      id: 'owner_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phone,
      address: Address(
        street: '',
        city: '',
        state: state,
        zipCode: zip,
        country: 'US',
      ),
      dateOfBirth: null,
    );
  }

  List<String> _parseConditionsList(String conditionsText) {
    final cleaned = conditionsText
        .split(RegExp(r'[\n,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return cleaned;
  }

  Future<void> _showDeclineDialog({
    required String petName,
    required String reason,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: ClovaraColors.kWarmCoral),
            const SizedBox(width: 12),
            const Text('Application Declined'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thanks for sharing $petName\'s details. Based on what you told us, we can\'t offer a new policy right now.',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(reason, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Text(
              'If you think something is off or you\'d like to discuss alternatives, our underwriting team can help.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/conversational-quote');
            },
            child: const Text('Chat with Clover'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StepMeta {
  final String title;
  final String subtitle;

  const _StepMeta({required this.title, required this.subtitle});
}

class _StepCard extends StatelessWidget {
  final Widget child;

  const _StepCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClovaraColors.clover.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClovaraColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ClovaraColors.clover),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ClovaraTypography.label.copyWith(
                    color: ClovaraColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: ClovaraTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final List<_ReviewRow> rows;

  const _ReviewSection({
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClovaraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ClovaraTypography.label.copyWith(
                    color: ClovaraColors.forest,
                  ),
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.slate.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
