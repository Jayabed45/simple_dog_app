import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const DogApp());
}

class DogApp extends StatelessWidget {
  const DogApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pawsome Gallery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EA), // Deep purple
          secondary: const Color(0xFFFF6D00), // Bright orange
          tertiary: const Color(0xFF00BFA5), // Teal
          brightness: Brightness.light,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF6200EA),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Dog {
  final String imageUrl;
  final String breed;
  final bool isFavorite;

  Dog({required this.imageUrl, required this.breed, this.isFavorite = false});

  Dog copyWith({bool? isFavorite}) {
    return Dog(
      imageUrl: imageUrl,
      breed: breed,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentPageIndex = 0;
  late TabController _tabController;

  // Shared state for all tabs
  final List<Dog> _allDogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentPageIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Pawsome Gallery',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            foreground:
                Paint()
                  ..shader = const LinearGradient(
                    colors: [Color(0xFF6200EA), Color(0xFF00BFA5)],
                  ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Pawsome Gallery',
                applicationVersion: '2.0.0',
                applicationLegalese: '©2025 Dog Lovers',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Discover and favorite adorable dog images from around the world!',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DiscoverScreen(
            allDogs: _allDogs,
            onDogAdded: (dog) {
              setState(() {
                _allDogs.add(dog);
              });
            },
            onDogUpdated: (index, dog) {
              setState(() {
                _allDogs[index] = dog;
              });
            },
          ),
          FavoritesScreen(
            dogs: _allDogs.where((dog) => dog.isFavorite).toList(),
            onDogUpdated: (dog) {
              final index = _allDogs.indexWhere(
                (d) => d.imageUrl == dog.imageUrl,
              );
              if (index != -1) {
                setState(() {
                  _allDogs[index] = dog;
                });
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(
                Icons.pets,
                color:
                    _currentPageIndex == 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
              ),
              text: 'Discover',
            ),
            Tab(
              icon: Icon(
                _currentPageIndex == 1 ? Icons.favorite : Icons.favorite_border,
                color:
                    _currentPageIndex == 1
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey,
              ),
              text: 'Favorites',
            ),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
        ),
      ),
    );
  }
}

class DiscoverScreen extends StatefulWidget {
  final List<Dog> allDogs;
  final Function(Dog) onDogAdded;
  final Function(int, Dog) onDogUpdated;

  const DiscoverScreen({
    required this.allDogs,
    required this.onDogAdded,
    required this.onDogUpdated,
    Key? key,
  }) : super(key: key);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  Dog? currentDog;
  bool isLoading = false;
  String? errorMessage;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (widget.allDogs.isEmpty) {
      fetchRandomDog();
    } else {
      currentDog = widget.allDogs.first;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _extractBreed(String url) {
    final urlParts = url.split('/');
    if (urlParts.length >= 5) {
      String breed = urlParts[4];

      // Handle hyphens for sub-breeds
      if (breed.contains('-')) {
        final parts = breed.split('-');
        breed = '${parts[1]} ${parts[0]}';
      }

      // Capitalize words
      return breed
          .split(' ')
          .map(
            (word) =>
                word.isNotEmpty
                    ? '${word[0].toUpperCase()}${word.substring(1)}'
                    : '',
          )
          .join(' ');
    }
    return 'Unknown';
  }

  Future<void> fetchRandomDog() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://dog.ceo/api/breeds/image/random'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String imageUrl = data['message'];
        final String breed = _extractBreed(imageUrl);

        final newDog = Dog(imageUrl: imageUrl, breed: breed);

        setState(() {
          currentDog = newDog;
          isLoading = false;
        });

        _animationController.reset();
        _animationController.forward();

        widget.onDogAdded(newDog);
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load dog image. Please try again.';
      });
    }
  }

  void toggleFavorite() {
    if (currentDog != null) {
      final index = widget.allDogs.indexWhere(
        (dog) => dog.imageUrl == currentDog!.imageUrl,
      );

      if (index != -1) {
        final updatedDog = widget.allDogs[index].copyWith(
          isFavorite: !widget.allDogs[index].isFavorite,
        );

        setState(() {
          currentDog = updatedDog;
        });

        widget.onDogUpdated(index, updatedDog);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? _buildErrorView()
              : _buildDogView(),
    );
  }

  Widget _buildDogView() {
    if (currentDog == null) {
      return const Center(child: Text('No dogs found'));
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _animation,
                child: Hero(
                  tag: currentDog!.imageUrl,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Dog image
                        Image.network(
                          currentDog!.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 64),
                              ),
                            );
                          },
                        ),

                        // Breed label with gradient
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentDog!.breed,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.pets,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            "Pawsome Friend",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: toggleFavorite,
                                    customBorder: const CircleBorder(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        transitionBuilder: (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          );
                                        },
                                        child: Icon(
                                          currentDog!.isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          key: ValueKey<bool>(
                                            currentDog!.isFavorite,
                                          ),
                                          color:
                                              currentDog!.isFavorite
                                                  ? Colors.red
                                                  : Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: fetchRandomDog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh),
                  const SizedBox(width: 8),
                  Text(
                    'Find Another Dog',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: fetchRandomDog,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  final List<Dog> dogs;
  final Function(Dog) onDogUpdated;

  const FavoritesScreen({
    required this.dogs,
    required this.onDogUpdated,
    Key? key,
  }) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool isGridView = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.dogs.length} Favorites',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isGridView ? Icons.view_list : Icons.grid_view,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        isGridView = !isGridView;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  widget.dogs.isEmpty
                      ? _buildEmptyView()
                      : isGridView
                      ? _buildGridView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border,
              size: 80,
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No favorite dogs yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Start marking dogs as favorites to see them here!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              DefaultTabController.of(context).animateTo(0);
            },
            icon: const Icon(Icons.pets),
            label: const Text('Discover Dogs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: widget.dogs.length,
      itemBuilder: (context, index) {
        return _buildDogCard(context, widget.dogs[index]);
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.dogs.length,
      itemBuilder: (context, index) {
        return _buildDogListItem(context, widget.dogs[index]);
      },
    );
  }

  Widget _buildDogCard(BuildContext context, Dog dog) {
    return Hero(
      tag: dog.imageUrl,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              dog.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value:
                        loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dog.breed,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white.withOpacity(0.8),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    widget.onDogUpdated(dog.copyWith(isFavorite: false));
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.favorite,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
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

  Widget _buildDogListItem(BuildContext context, Dog dog) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Hero(
              tag: "${dog.imageUrl}-list",
              child: Image.network(dog.imageUrl, fit: BoxFit.cover),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dog.breed,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Added to favorites',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.favorite,
              color: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () {
              widget.onDogUpdated(dog.copyWith(isFavorite: false));
            },
          ),
        ],
      ),
    );
  }
}
