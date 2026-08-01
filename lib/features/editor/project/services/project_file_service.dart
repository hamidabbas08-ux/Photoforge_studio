import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/photoforge_project.dart';

class ProjectFileService {
  ProjectFileService._();

  static final ProjectFileService instance = ProjectFileService._();

  Future<Directory> get projectsDirectory async {
    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Projects',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<File> saveProject(PhotoForgeProject project) async {
    final Directory directory = await projectsDirectory;

    final String safeName = project.projectName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final String fileName = safeName.isEmpty ? 'Untitled_Project' : safeName;

    final File file = File('${directory.path}/$fileName.photoforge');

    final String jsonText = const JsonEncoder.withIndent(
      '  ',
    ).convert(project.toJson());

    await file.writeAsString(jsonText, flush: true);

    return file;
  }

  Future<PhotoForgeProject> loadProject(File file) async {
    if (!await file.exists()) {
      throw StateError('Project file does not exist.');
    }

    final String jsonText = await file.readAsString();

    final Object? decoded = jsonDecode(jsonText);

    if (decoded is! Map) {
      throw const FormatException('Invalid PhotoForge project file.');
    }

    return PhotoForgeProject.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<List<File>> listProjects() async {
    final Directory directory = await projectsDirectory;

    final List<File> projects = await directory
        .list()
        .where(
          (FileSystemEntity entity) =>
              entity is File && entity.path.endsWith('.photoforge'),
        )
        .cast<File>()
        .toList();

    projects.sort((File first, File second) {
      return second.lastModifiedSync().compareTo(first.lastModifiedSync());
    });

    return projects;
  }

  Future<void> deleteProject(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
