class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String phoneNumber;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Patient',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
    };
  }
}
