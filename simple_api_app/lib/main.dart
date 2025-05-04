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
      title: 'Dog Gallery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6572),
          secondary: const Color(0xFFF9AA33),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
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

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;

  // Shared state for all tabs
  final List<Dog> _allDogs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentPageIndex,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentPageIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
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

class _DiscoverScreenState extends State<DiscoverScreen> {
  Dog? currentDog;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.allDogs.isEmpty) {
      fetchRandomDog();
    } else {
      currentDog = widget.allDogs.first;
    }
  }

  String _extractBreed(String url) {
    final urlParts = url.split('/');
    if (urlParts.length >= 5) {
      String breed = urlParts[4];

      // Handle hyphens for sub-breeds
      if (breed.contains('-')) {
        final parts = breed.split('-');
        breed = '${parts[0]} ${parts[1]}';
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
      appBar: AppBar(
        title: const Text(
          'Dog Gallery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
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

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Dog image
                    Image.network(
                      currentDog!.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
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

                    // Breed label
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                currentDog!.breed,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                currentDog!.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    currentDog!.isFavorite
                                        ? Colors.red
                                        : Colors.white,
                              ),
                              onPressed: toggleFavorite,
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

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: fetchRandomDog,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Random Dog'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(errorMessage ?? 'Something went wrong'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: fetchRandomDog,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  final List<Dog> dogs;
  final Function(Dog) onDogUpdated;

  const FavoritesScreen({
    required this.dogs,
    required this.onDogUpdated,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites'), centerTitle: true),
      body:
          dogs.isEmpty
              ? _buildEmptyView()
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: dogs.length,
                itemBuilder: (context, index) {
                  return _buildDogCard(context, dogs[index]);
                },
              ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No favorite dogs yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Start marking dogs as favorites!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDogCard(BuildContext context, Dog dog) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(dog.imageUrl, fit: BoxFit.cover),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dog.breed,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
              color: Colors.white.withOpacity(0.7),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () {
                  onDogUpdated(dog.copyWith(isFavorite: false));
                },
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.favorite, color: Colors.red, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
