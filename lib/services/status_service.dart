import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/status_story.dart';

final statusProvider = StateNotifierProvider<StatusNotifier, StatusStory?>(
  (ref) => StatusNotifier(),
);

class StatusNotifier extends StateNotifier<StatusStory?> {
  StatusNotifier() : super(null) {
    _loadInitialStatus();
  }

  void _loadInitialStatus() {
    // Mocking a status for now.
    // In production, this would fetch from an API.
    state = StatusStory(
      id: 'mock-1',
      imageUrls: [
        'https://images.unsplash.com/photo-1775565813524-67c12bae1439?q=80&w=2016&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D?q=80&w=1000&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1774840966298-639fb936b382?q=80&w=687&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D?q=80&w=1000&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1768744781410-757053db2ab0?q=80&w=693&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D?q=80&w=1000&auto=format&fit=crop',
      ],
      timestamp: DateTime.now(),
    );
  }

  void markAsSeen() {
    if (state != null) {
      state = state!.copyWith(isSeen: true);
    }
  }

  void reset() {
    _loadInitialStatus();
  }
}
