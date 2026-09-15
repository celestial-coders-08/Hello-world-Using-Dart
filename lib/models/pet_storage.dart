import 'dart:core';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

class LocalPetStorage implements IPetStorage {
  static const String _petKeyPrefix = 'pet_profile_';

  String _keyForUser(String userId) =>
      '$_petKeyPrefix${Uri.encodeComponent(userId.trim())}';

  @override
  Future<void> savePet(Pet pet) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _keyForUser(pet.userId),
      jsonEncode(pet.toJson()),
    );
  }

  Future<Pet?> loadPetIfExists(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final encodedPet = preferences.getString(_keyForUser(userId));
    if (encodedPet == null || encodedPet.isEmpty) return null;

    return Pet.fromJson(jsonDecode(encodedPet) as Map<String, dynamic>);
  }

  @override
  Future<Pet> loadPet(String userId) async {
    final pet = await loadPetIfExists(userId);
    if (pet == null) {
      throw StateError('No pet profile saved for this user.');
    }
    return pet;
  }

  @override
  Future<void> deletePet(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keyForUser(userId));
  }

  @override
  Future<List<Pet>> getAllPetsByType(String petType) async {
    return [];
  }

  @override
  Future<void> saveProfilePhoto(String assetPath) async {}

  @override
  Future<String> getProfilePhoto() async => 'default_profile.jpg';
}
