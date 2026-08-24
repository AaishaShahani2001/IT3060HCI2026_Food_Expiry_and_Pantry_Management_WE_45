import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../data/onboarding_data.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_page.dart';
import '../widgets/page_indicator.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goHome() {
    context.go(AppRoutes.home);
  }

  void _onNext() {
    final currentIndex = ref.read(onboardingPageIndexProvider);
    if (currentIndex < OnboardingData.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(onboardingPageIndexProvider);
    final isLastPage = currentIndex == OnboardingData.items.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isLastPage
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _goHome,
                          child: const Text(AppStrings.skip),
                        ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: OnboardingData.items.length,
                  onPageChanged: (index) {
                    ref
                        .read(onboardingPageIndexProvider.notifier)
                        .setPage(index);
                  },
                  itemBuilder: (context, index) {
                    return OnboardingPage(item: OnboardingData.items[index]);
                  },
                ),
              ),
              PageIndicator(
                count: OnboardingData.items.length,
                currentIndex: currentIndex,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLastPage ? _goHome : _onNext,
                  child: Text(
                    isLastPage ? AppStrings.getStarted : AppStrings.next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
