class UserSocialLoginDeatilModal {
  String socialLoginId;
  String emailId;
  String userName;
  UserSocialLoginDeatilModal({
    required this.socialLoginId,
    required this.emailId,
    required this.userName,
  });

  toJson() {
    Map<String, dynamic> data = {};
    data["socialLoginId"] = socialLoginId;
    data["emailId"] = emailId;
    data["userName"] = userName;
    return data;
  }
}
