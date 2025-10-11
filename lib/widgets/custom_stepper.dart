import 'package:flutter/material.dart';

/// Custom stepper widget for multi-step forms
class CustomStepper extends StatelessWidget {
  final int currentStep;
  final List<StepData> steps;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  
  const CustomStepper({
    super.key,
    required this.currentStep,
    required this.steps,
    this.onNext,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStepIndicator(),
        const SizedBox(height: 24),
        Expanded(
          child: steps[currentStep].content,
        ),
        _buildNavigationButtons(),
      ],
    );
  }
  
  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          return _buildStepCircle(stepIndex);
        } else {
          return Expanded(
            child: Container(
              height: 2,
              color: currentStep > index ~/ 2 ? Colors.blue : Colors.grey[300],
            ),
          );
        }
      }),
    );
  }
  
  Widget _buildStepCircle(int stepIndex) {
    final isCompleted = stepIndex < currentStep;
    final isActive = stepIndex == currentStep;
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isCompleted || isActive ? Colors.blue : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                '${stepIndex + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
  
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (currentStep > 0)
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: onNext,
            child: Text(currentStep < steps.length - 1 ? 'Next' : 'Submit'),
          ),
        ],
      ),
    );
  }
}

class StepData {
  final String title;
  final Widget content;
  
  StepData({required this.title, required this.content});
}
