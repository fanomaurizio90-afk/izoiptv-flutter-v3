class UserInfo {
  const UserInfo({
    required this.username,
    required this.status,
    this.expiryDate,
    this.maxConnections,
    this.activeCons,
    this.isTrial,
    this.displayName,
    this.subscriptionPlan,
    this.loginType = 'xtream',
    this.serverUrl,
  });
  final String  username;
  final String  status;
  final String? expiryDate;
  final int?    maxConnections;
  final int?    activeCons;
  final bool?   isTrial;
  final String? displayName;
  final String? subscriptionPlan;
  final String  loginType;
  final String? serverUrl;
}
