import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/dashboard_card.dart';

enum ResourceCategory {
  fertility,
  investigations,
  treatment,
  procedures,
  medication,
  maleFertility,
  wellness,
  faq,
}

class EducationResource {
  final String id;
  final String title;
  final ResourceCategory category;
  final String description;
  final String? content;

  const EducationResource({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.content,
  });
}

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final _resources = const <EducationResource>[
    EducationResource(
      id: 'fertility-basics',
      title: 'Understanding fertility',
      category: ResourceCategory.fertility,
      description: 'General fertility education will be published here when approved content is available.',
    ),
    EducationResource(
      id: 'treatment-preparation',
      title: 'Preparing for treatment',
      category: ResourceCategory.treatment,
      description: 'Clinic-approved preparation guidance is not available in this prototype.',
    ),
  ];
  Set<String> _bookmarks = {};
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bookmarks =
          preferences.getStringList('education_bookmarks')?.toSet() ?? {};
      _loading = false;
    });
  }

  Future<void> _toggleBookmark(EducationResource resource) async {
    final next = {..._bookmarks};
    if (!next.add(resource.id)) next.remove(resource.id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('education_bookmarks', next.toList());
    if (mounted) setState(() => _bookmarks = next);
  }

  String _categoryLabel(ResourceCategory category) => switch (category) {
    ResourceCategory.fertility => 'Understanding fertility',
    ResourceCategory.investigations => 'Fertility investigations',
    ResourceCategory.treatment => 'Treatment information',
    ResourceCategory.procedures => 'Preparing for procedures',
    ResourceCategory.medication => 'Medication information',
    ResourceCategory.maleFertility => 'Male fertility',
    ResourceCategory.wellness => 'Lifestyle and wellness',
    ResourceCategory.faq => 'Frequently asked questions',
  };

  @override
  Widget build(BuildContext context) {
    final visible = _resources
        .where(
          (resource) =>
              resource.title.toLowerCase().contains(_query.toLowerCase()) ||
              _categoryLabel(resource.category)
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: LocalizedText('Education Centre'),
        actions: [
          IconButton(
            tooltip: localizedText(context, 'Saved resources'),
            onPressed: () => setState(() => _query = ''),
            icon: const Icon(Icons.bookmark_border),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                DashboardCard(
                  color: AppColors.burgundy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'GENERAL EDUCATION',
                        style: TextStyle(
                          color: AppColors.dustyPink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LocalizedText(
                        'Learn at your pace',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      LocalizedText(
                        'Education is general information, not personalised medical advice.',
                        style: TextStyle(color: AppColors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: localizedText(context, 'Search resources'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LocalizedText(
                  'RESOURCE CATEGORIES',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ResourceCategory.values
                      .map(
                        (category) => ActionChip(
                          label: LocalizedText(_categoryLabel(category)),
                          onPressed: () =>
                              setState(() => _query = _categoryLabel(category)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                LocalizedText(
                  'FEATURED RESOURCES',
                  style: TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  const DashboardCard(
                    child: LocalizedText(
                      'No resources match your search.',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  )
                else
                  ...visible.map((resource) => _resourceCard(resource)),
                const SizedBox(height: 12),
                const DashboardCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.ondemand_video_outlined,
                        color: AppColors.dustyPink,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: LocalizedText(
                          'Video resources are not available because no verified clinic video links are configured.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _resourceCard(EducationResource resource) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DashboardCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          resource.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: LocalizedText(
          '${_categoryLabel(resource.category)}\n${resource.description}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(
            _bookmarks.contains(resource.id)
                ? Icons.bookmark
                : Icons.bookmark_border,
            color: AppColors.burgundy,
          ),
          onPressed: () => _toggleBookmark(resource),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailsScreen(
              resource: resource,
              bookmarked: _bookmarks.contains(resource.id),
              onBookmarkChanged: () => _toggleBookmark(resource),
            ),
          ),
        ),
      ),
    ),
  );
}

class ArticleDetailsScreen extends StatelessWidget {
  final EducationResource resource;
  final bool bookmarked;
  final VoidCallback onBookmarkChanged;

  const ArticleDetailsScreen({
    super.key,
    required this.resource,
    required this.bookmarked,
    required this.onBookmarkChanged,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: LocalizedText('Resource details'),
      actions: [
        IconButton(
          onPressed: onBookmarkChanged,
          icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
        ),
      ],
    ),
    backgroundColor: AppColors.background,
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          resource.title,
          style: const TextStyle(
            color: AppColors.burgundy,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          resource.description,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        DashboardCard(
          child: Text(
            resource.content ?? 'Approved educational content is not available yet. This placeholder is intentionally not presented as clinic guidance or personalised medical advice.',
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
