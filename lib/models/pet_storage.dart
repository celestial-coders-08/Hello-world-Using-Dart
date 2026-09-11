import 'dart:core';

/// Pet model representing a pet profile
class Pet {
  final String userId;
  final String name;
  final String type;
  final int age;
  final String dietaryPreferences;
  final String healthStatus;
  final String? profileImage;

  Pet({
    required this.userId,
    required this.name,
    required this.type,
    required this.age,
    required this.dietaryPreferences,
    required this.healthStatus,
    this.profileImage,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      age: (json['age'] as int?) ?? 1,
      dietaryPreferences: json['dietary_preferences'] as String,
      healthStatus: json['health_status'] as String,
      profileImage: json['profile_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'type': type,
    'age': age,
    'dietary_preferences': dietaryPreferences,
    'health_status': healthStatus,
    if (profileImage != null) 'profile_image': profileImage,
  };
}

/// Pet storage abstraction
abstract class IPetStorage {
  Future<void> savePet(Pet pet);
  Future<Pet> loadPet(String userId);
  Future<void> deletePet(String userId);
  Future<List<Pet>> getAllPetsByType(String petType);
  Future<void> saveProfilePhoto(String assetPath);
  Future<String> getProfilePhoto();
}

/// Dummy implementation
class DummyPetStorage implements IPetStorage {
  @override
  Future<void> savePet(Pet pet) async {}

  @override
  Future<Pet> loadPet(String userId) async {
    return Pet(
      userId: userId,
      name: 'dummyPet',
      type: 'Dog',
      age: 3,
      dietaryPreferences: 'Sample dietary info',
      healthStatus: 'Sample health info',
    );
  }

  @override
  Future<void> deletePet(String userId) async {}

  @override
  Future<List<Pet>> getAllPetsByType(String petType) async {
    return [
      Pet(
        userId: 'dummy$petType',
        name: 'dummyPet',
        type: petType,
        age: 3,
        dietaryPreferences: 'Sample dietary info',
        healthStatus: 'Sample health info',
      ),
    ];
  }

  @override
  Future<void> saveProfilePhoto(String assetPath) async {}

  @override
  Future<String> getProfilePhoto() async => 'default_profile.jpg';
}
