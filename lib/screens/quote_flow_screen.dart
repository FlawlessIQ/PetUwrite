import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';

/// Quote flow screen for getting insurance quotes
class QuoteFlowScreen extends StatefulWidget {
  const QuoteFlowScreen({super.key});

  @override
  State<QuoteFlowScreen> createState() => _QuoteFlowScreenState();
}

class _QuoteFlowScreenState extends State<QuoteFlowScreen> {
  int _currentStep = 0;
  
  // Form data
  final Map<String, dynamic> _formData = {};
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get a Quote'),
        elevation: 0,
        actions: [
          // Show login/account button
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // User is logged in - show account icon
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.account_circle),
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'dashboard') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerHomeScreen(isPremium: false),
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
              } else {
                // User not logged in - show login button
                return TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Login'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        onStepTapped: (step) => setState(() => _currentStep = step),
        steps: [
          Step(
            title: const Text('Pet Information'),
            content: _buildPetInfoStep(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Owner Information'),
            content: _buildOwnerInfoStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Medical History'),
            content: _buildMedicalHistoryStep(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Review & Submit'),
            content: _buildReviewStep(),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPetInfoStep() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Pet Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _formData['petName'] = value,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Species',
            border: OutlineInputBorder(),
          ),
          items: ['Dog', 'Cat'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) => _formData['species'] = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Breed',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _formData['breed'] = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Date of Birth',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              _formData['dateOfBirth'] = date;
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildOwnerInfoStep() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'First Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _formData['firstName'] = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Last Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _formData['lastName'] = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (value) => _formData['email'] = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (value) => _formData['phone'] = value,
        ),
      ],
    );
  }
  
  Widget _buildMedicalHistoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Veterinary Records',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement file picker
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Records'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Pre-existing Conditions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'List any known conditions',
            border: OutlineInputBorder(),
            hintText: 'e.g., Arthritis, Allergies',
          ),
          maxLines: 3,
          onChanged: (value) => _formData['conditions'] = value,
        ),
      ],
    );
  }
  
  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Your Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildReviewItem('Pet Name', _formData['petName'] ?? 'N/A'),
        _buildReviewItem('Species', _formData['species'] ?? 'N/A'),
        _buildReviewItem('Breed', _formData['breed'] ?? 'N/A'),
        _buildReviewItem('Owner', '${_formData['firstName'] ?? ''} ${_formData['lastName'] ?? ''}'),
        _buildReviewItem('Email', _formData['email'] ?? 'N/A'),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitQuote,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('Get Quote'),
          ),
        ),
      ],
    );
  }
  
  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }
  
  void _onStepContinue() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }
  
  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }
  
  void _submitQuote() {
    // Pass form data to plan selection
    Navigator.pushNamed(
      context,
      '/plan-selection',
      arguments: _formData,
    );
  }
}
