import '../datasources/remote/api_service.dart';

class SupportResource {
  final int id;
  final String type;
  final String title;
  final String description;
  final String? modality;
  final String? location;
  final DateTime? startAt;
  final int? availableSeats;
  final String? url;
  final List<String> tags;
  final bool isSynthetic;

  const SupportResource({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.modality,
    this.location,
    this.startAt,
    this.availableSeats,
    this.url,
    this.tags = const [],
    this.isSynthetic = false,
  });

  factory SupportResource.fromJson(Map<String, dynamic> json) =>
      SupportResource(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        modality: json['modality'] as String?,
        location: json['location'] as String?,
        startAt: DateTime.tryParse(json['startAt'] as String? ?? ''),
        availableSeats: (json['availableSeats'] as num?)?.toInt(),
        url: json['url'] as String?,
        tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
        isSynthetic: json['isSynthetic'] == true,
      );
}

abstract class AcademicSupportRepository {
  Future<List<SupportResource>> resources(String type);
  Future<List<SupportResource>> recommendations();
  Future<Map<String, dynamic>> preferences();
  Future<void> savePreferences(Map<String, dynamic> value);
  Future<void> interact(int id, String eventType);
  Future<void> enroll(int id);
  Future<void> cancelEnrollment(int id);
  Future<Set<int>> enrollments();
}

class HttpAcademicSupportRepository implements AcademicSupportRepository {
  final ApiService _api;
  final String _base;
  HttpAcademicSupportRepository(this._api, String base)
    : _base = base.replaceAll(RegExp(r'/+$'), '');

  @override
  Future<List<SupportResource>> resources(String type) async {
    final response = await _api.get('$_base/resources?type=$type');
    return (response['items'] as List<dynamic>)
        .map((item) => SupportResource.fromJson(item as Map<String, dynamic>))
        .where((resource) => !resource.isSynthetic)
        .toList();
  }

  @override
  Future<List<SupportResource>> recommendations() async {
    final response = await _api.get('$_base/recommendations');
    return (response['items'] as List<dynamic>)
        .map(
          (item) => SupportResource.fromJson(
            (item as Map<String, dynamic>)['resource'] as Map<String, dynamic>,
          ),
        )
        .where((resource) => !resource.isSynthetic)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> preferences() =>
      _api.get('$_base/students/me/preferences');

  @override
  Future<void> savePreferences(Map<String, dynamic> value) async {
    await _api.put('$_base/students/me/preferences', body: value);
  }

  @override
  Future<void> interact(int id, String eventType) async {
    await _api.post(
      '$_base/interactions',
      body: {'resourceId': id, 'eventType': eventType},
      expectedStatus: 201,
    );
  }

  @override
  Future<void> enroll(int id) async {
    await _api.post('$_base/workshops/$id/enroll', expectedStatus: 201);
  }

  @override
  Future<void> cancelEnrollment(int id) async {
    await _api.delete('$_base/workshops/$id/enroll');
  }

  @override
  Future<Set<int>> enrollments() async {
    final response = await _api.get('$_base/students/me/enrollments');
    return (response['items'] as List<dynamic>)
        .map(
          (item) =>
              ((item as Map<String, dynamic>)['resourceId'] as num).toInt(),
        )
        .toSet();
  }
}
