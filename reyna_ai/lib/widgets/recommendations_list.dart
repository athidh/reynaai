import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'gradient_button.dart';

class RecommendationsList extends StatefulWidget {
  final String domainInterest;
  const RecommendationsList({super.key, required this.domainInterest});

  @override
  State<RecommendationsList> createState() => _RecommendationsListState();
}

class _RecommendationsListState extends State<RecommendationsList> {
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    final state = context.read<AppState>();
    final token = state.token;
    if (token == null) {
      if (mounted) setState(() { _isLoading = false; _error = 'Unauthenticated'; });
      return;
    }

    try {
      // Modify query slightly to ensure actionable insights, e.g. "Study tips for <domain>"
      final results = await ApiService.searchVideos(token, "Study techniques for ${widget.domainInterest}");
      if (mounted) {
        setState(() {
          _videos = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load recommendations';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AppColors.error)),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Text('No recommendations found at this time.',
            style: TextStyle(color: AppColors.outline, fontFamily: 'Manrope')),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        final videoId = video['id']?['videoId'] ?? '';
        final snippet = video['snippet'] ?? {};
        final title = snippet['title'] ?? 'Unknown Video';
        final channelTitle = snippet['channelTitle'] ?? '';
        final thumbUrl = snippet['thumbnails']?['medium']?['url'] ?? '';

        return Container(
          width: 260,
          margin: EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                child: thumbUrl.isNotEmpty
                    ? Image.network(
                        thumbUrl,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: AppColors.surfaceContainerHighest,
                          child: Icon(Icons.broken_image, color: AppColors.outline),
                        ),
                      )
                    : Container(
                        height: 120,
                        color: AppColors.surfaceContainerHighest,
                        child: Icon(Icons.video_library, color: AppColors.outline),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Parse HTML entities like &#39;
                        title.replaceAll('&amp;', '&').replaceAll('&#39;', "'").replaceAll('&quot;', '"'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: GradientButton(
                          text: 'Watch Now',
                          onTap: () {
                            if (videoId.isEmpty) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Training Arena coming soon!')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
