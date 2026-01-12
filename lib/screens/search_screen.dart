import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../widgets/search_result_item.dart';
import 'notebook_screen.dart';
import '../providers/notebooks_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<SearchProvider>().search(query);
  }

  void _navigateToEntry(Map<String, dynamic> result) async {
    final notebookId = result['notebook_id'] as String;
    final notebook = await context.read<NotebooksProvider>().getNotebook(
      notebookId,
    );

    if (notebook != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NotebookScreen(notebook: notebook)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search all notebooks...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                context.read<SearchProvider>().clearSearch();
              },
            ),
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, provider, _) {
          if (provider.isSearching) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.query.isEmpty) {
            return _buildEmptyPrompt();
          }

          if (provider.results.isEmpty) {
            return _buildNoResults();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.results.length,
            itemBuilder: (context, index) {
              final result = provider.results[index];
              final entry = provider.getEntryFromResult(result);

              return SearchResultItem(
                entry: entry,
                notebookTitle: provider.getNotebookTitle(result),
                notebookColor: provider.getNotebookColor(result),
                query: provider.query,
                onTap: () => _navigateToEntry(result),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Search your entries',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find entries across all your notebooks',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
