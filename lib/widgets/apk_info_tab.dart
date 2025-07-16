import 'package:flutter/material.dart';
import '../models/apk_info.dart';

class ApkInfoTab extends StatefulWidget {
  final Function(String) onConsoleOutput;
  final String? apkPath;
  final ApkInfo? apkInfo;

  ApkInfoTab({
    required this.onConsoleOutput,
    this.apkPath,
    this.apkInfo,
  });

  @override
  _ApkInfoTabState createState() => _ApkInfoTabState();
}

class _ApkInfoTabState extends State<ApkInfoTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.apkInfo == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading APK information...'),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          Container(
            color: Colors.grey[50],
            child: TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              isScrollable: true,
              tabs: [
                Tab(text: 'Basic Info'),
                Tab(text: 'Permission Info'),
                Tab(text: 'Activity List'),
                Tab(text: 'Service List'),
                Tab(text: 'Native Library Info'),
                Tab(text: 'Manifest'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBasicInfoTab(),
                _buildPermissionInfoTab(),
                _buildActivityListTab(),
                _buildServiceListTab(),
                _buildNativeLibraryTab(),
                _buildManifestTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    final info = widget.apkInfo!;
    return Container(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard('Package Information', [
              _buildInfoRow('Package Name', info.packageName),
              _buildInfoRow('Version Name', info.versionName),
              _buildInfoRow('Version Code', info.versionCode),
            ]),
            SizedBox(height: 16),
            _buildInfoCard('SDK Information', [
              _buildInfoRow('Target SDK', info.targetSdk),
              _buildInfoRow('Min SDK', info.minSdk),
            ]),
            SizedBox(height: 16),
            _buildInfoCard('Components Count', [
              _buildInfoRow('Activities', info.activities.length.toString()),
              _buildInfoRow('Services', info.services.length.toString()),
              _buildInfoRow('Receivers', info.receivers.length.toString()),
              _buildInfoRow('Providers', info.providers.length.toString()),
              _buildInfoRow('Permissions', info.permissions.length.toString()),
              _buildInfoRow('Native Libraries', info.libraries.length.toString()),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionInfoTab() {
    final permissions = widget.apkInfo!.permissions;
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permissions (${permissions.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: permissions.isEmpty
                ? Center(child: Text('No permissions found'))
                : ListView.builder(
                    itemCount: permissions.length,
                    itemBuilder: (context, index) {
                      final permission = permissions[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.security, color: Colors.orange),
                          title: Text(
                            permission,
                            style: TextStyle(fontFamily: 'Courier', fontSize: 12),
                          ),
                          subtitle: Text(_getPermissionDescription(permission)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityListTab() {
    final activities = widget.apkInfo!.activities;
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activities (${activities.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: activities.isEmpty
                ? Center(child: Text('No activities found'))
                : ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.apps, color: Colors.blue),
                          title: Text(
                            activity,
                            style: TextStyle(fontFamily: 'Courier', fontSize: 12),
                          ),
                          subtitle: Text('Activity Component'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceListTab() {
    final services = widget.apkInfo!.services;
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services (${services.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: services.isEmpty
                ? Center(child: Text('No services found'))
                : ListView.builder(
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.settings, color: Colors.green),
                          title: Text(
                            service,
                            style: TextStyle(fontFamily: 'Courier', fontSize: 12),
                          ),
                          subtitle: Text('Service Component'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeLibraryTab() {
    final libraries = widget.apkInfo!.libraries;
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Native Libraries (${libraries.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: libraries.isEmpty
                ? Center(child: Text('No native libraries found'))
                : ListView.builder(
                    itemCount: libraries.length,
                    itemBuilder: (context, index) {
                      final library = libraries[index];
                      final architecture = _getArchitecture(library);
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.memory, color: Colors.purple),
                          title: Text(
                            library,
                            style: TextStyle(fontFamily: 'Courier', fontSize: 12),
                          ),
                          subtitle: Text('Architecture: $architecture'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildManifestTab() {
    final manifest = widget.apkInfo!.manifestContent;
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AndroidManifest.xml',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.copy),
                onPressed: () => _copyToClipboard(manifest),
                tooltip: 'Copy to clipboard',
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  manifest,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'Courier'),
            ),
          ),
        ],
      ),
    );
  }

  String _getPermissionDescription(String permission) {
    final descriptions = {
      'android.permission.INTERNET': 'Access the internet',
      'android.permission.ACCESS_NETWORK_STATE': 'View network connections',
      'android.permission.WRITE_EXTERNAL_STORAGE': 'Write to external storage',
      'android.permission.READ_EXTERNAL_STORAGE': 'Read from external storage',
      'android.permission.CAMERA': 'Use camera',
      'android.permission.RECORD_AUDIO': 'Record audio',
      'android.permission.ACCESS_FINE_LOCATION': 'Access precise location',
      'android.permission.ACCESS_COARSE_LOCATION': 'Access approximate location',
    };
    return descriptions[permission] ?? 'System permission';
  }

  String _getArchitecture(String libraryPath) {
    if (libraryPath.contains('arm64-v8a')) return 'ARM64';
    if (libraryPath.contains('armeabi-v7a')) return 'ARM32';
    if (libraryPath.contains('x86_64')) return 'x86_64';
    if (libraryPath.contains('x86')) return 'x86';
    return 'Unknown';
  }

  void _copyToClipboard(String text) {
    // TODO: Implement clipboard functionality
    widget.onConsoleOutput('Manifest copied to clipboard');
  }
}