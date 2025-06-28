import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  const ProfilePage({Key? key, this.onProfileUpdated}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _name;
  String? _avatarUrl;
  String? _email;
  bool _loading = true;

  // Fetch profile dari Supabase
  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final response = await Supabase.instance.client
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    setState(() {
      _name = response != null ? response['name'] as String? : null;
      _avatarUrl = response != null ? response['avatar_url'] as String? : null;
      _email = user.email;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage:
                          _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null || _avatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _name ?? '-',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_email ?? '-', style: GoogleFonts.poppins(fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => EditProfileDialog(
                          name: _name,
                          avatarUrl: _avatarUrl,
                          onProfileUpdated: () async {
                            await _fetchProfile();
                            setState(() {});
                            if (widget.onProfileUpdated != null)
                              widget.onProfileUpdated!();
                          },
                        ),
                      );
                    },
                    child: const Text('Edit Profil'),
                  ),
                ],
              ),
            ),
    );
  }
}

class EditProfileDialog extends StatefulWidget {
  final String? name;
  final String? avatarUrl;
  final VoidCallback onProfileUpdated;
  const EditProfileDialog({
    Key? key,
    this.name,
    this.avatarUrl,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String? _avatarUrl;
  bool _loading = false;
  String? _error;
  String _gravatarStyle = 'identicon';
  final List<String> _gravatarStyles = [
    'identicon',
    'monsterid',
    'wavatar',
    'retro',
    'robohash',
  ];
  final ImagePicker _picker = ImagePicker();
  String _avatarMode = 'upload'; // 'upload', 'gravatar', 'default'
  String? _uploadedUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name ?? '');
    _avatarUrl = widget.avatarUrl;
    _uploadedUrl = widget.avatarUrl;
  }

  String _gravatarUrl(String email, String style) {
    final hash = email.trim().toLowerCase().runes.fold<String>(
      '',
      (prev, c) => prev + c.toRadixString(16),
    );
    return 'https://www.gravatar.com/avatar/$hash?d=$style';
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      final fileName = picked.name.toLowerCase();
      final allowedExt = ['.jpg', '.jpeg', '.png'];
      if (!allowedExt.any((ext) => fileName.endsWith(ext))) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format file harus jpg, jpeg, atau png'),
            ),
          );
        return;
      }
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await picked.readAsBytes();
      } else {
        final file = File(picked.path);
        final fileSize = await file.length();
        if (fileSize > 2 * 1024 * 1024) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ukuran file maksimal 2MB')),
            );
          return;
        }
        bytes = await file.readAsBytes();
      }
      setState(() {
        _loading = true;
      });
      final fileExt = fileName.split('.').last;
      final storagePath =
          'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storage = Supabase.instance.client.storage;
      if (kIsWeb) {
        await storage
            .from('avatars')
            .uploadBinary(
              storagePath,
              bytes!,
              fileOptions: const FileOptions(upsert: true),
            );
      } else {
        final file = File(picked.path);
        await storage
            .from('avatars')
            .upload(
              storagePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
      }
      final publicUrl = storage.from('avatars').getPublicUrl(storagePath);
      setState(() {
        _uploadedUrl = publicUrl;
        _avatarMode = 'upload';
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar berhasil diupload!')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal upload avatar: $e')));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _resetAvatar() async {
    setState(() {
      _avatarMode = 'default';
      _uploadedUrl = null;
    });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar direset ke default.')),
      );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      final updateData = <String, dynamic>{'name': _nameController.text.trim()};

      if (_avatarMode == 'gravatar') {
        final userEmail = user.email;
        if (userEmail == null) {
          throw Exception('Email user tidak ditemukan untuk Gravatar');
        }
        updateData['avatar_url'] = _gravatarUrl(userEmail, _gravatarStyle);
        updateData['gravatar_style'] = _gravatarStyle;
        print('Saving Gravatar: ${updateData['avatar_url']}');
      } else if (_avatarMode == 'upload' && _uploadedUrl != null) {
        updateData['avatar_url'] = _uploadedUrl;
        updateData['gravatar_style'] = null;
        print('Saving Uploaded Avatar: ${updateData['avatar_url']}');
      } else if (_avatarMode == 'default') {
        updateData['avatar_url'] = null;
        updateData['gravatar_style'] = null;
        print('Saving Default Avatar (null URL)');
      }

      final result = await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', user.id)
          .select()
          .single();

      print('Supabase Update result: $result');

      if (result == null) {
        print(
          'No profile row found for user ID: ${user.id} or RLS denied access.',
        );
        setState(
          () => _error =
              'Gagal menyimpan: Profil tidak ditemukan atau akses ditolak.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil tidak ditemukan atau akses ditolak.'),
            ),
          );
        }
        return;
      }

      widget.onProfileUpdated();

      // Tutup dialog setelah berhasil
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      setState(() => _error = 'Gagal menyimpan profil: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _avatarPreview() {
    final user = Supabase.instance.client.auth.currentUser;
    if (_avatarMode == 'gravatar') {
      return CircleAvatar(
        radius: 36,
        backgroundImage: NetworkImage(
          _gravatarUrl(user?.email ?? '', _gravatarStyle),
        ),
      );
    } else if (_avatarMode == 'upload' &&
        _uploadedUrl != null &&
        _uploadedUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: NetworkImage(_uploadedUrl!),
      );
    } else {
      return const CircleAvatar(
        radius: 36,
        child: Icon(Icons.person, size: 36),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return AlertDialog(
      title: const Text('Edit Profil'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatarPreview(),
              const SizedBox(height: 16),
              ToggleButtons(
                isSelected: [
                  _avatarMode == 'upload',
                  _avatarMode == 'gravatar',
                  _avatarMode == 'default',
                ],
                onPressed: (index) {
                  setState(() {
                    if (index == 0) _avatarMode = 'upload';
                    if (index == 1) _avatarMode = 'gravatar';
                    if (index == 2) _resetAvatar();
                  });
                },
                borderRadius: BorderRadius.circular(12),
                selectedColor: Colors.white,
                fillColor: Theme.of(context).colorScheme.primary,
                color: Theme.of(context).colorScheme.onSurface,
                constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload, size: 18),
                        SizedBox(width: 6),
                        Text('Upload'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_circle, size: 18),
                        SizedBox(width: 6),
                        Text('Gravatar'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 18),
                        SizedBox(width: 6),
                        Text('Reset'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_avatarMode == 'upload')
                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickAndUploadAvatar,
                  icon: const Icon(Icons.upload),
                  label: const Text('Pilih Foto'),
                ),
              if (_avatarMode == 'gravatar')
                DropdownButton<String>(
                  value: _gravatarStyle,
                  items: _gravatarStyles
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _gravatarStyle = v!;
                  }),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
