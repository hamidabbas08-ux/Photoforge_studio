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

    final File projectFile = File('${directory.path}/$fileName.photoforge');

    final Directory assetsDirectory = Directory(
      '${directory.path}/assets/$fileName',
    );

    if (!await assetsDirectory.exists()) {
      await assetsDirectory.create(recursive: true);
    }

    final Map<String, Object?> projectJson = project.toJson();

    final List<Object?> rawLayers =
        projectJson['layers'] as List<Object?>? ?? <Object?>[];

    final List<Map<String, Object?>> savedLayers = <Map<String, Object?>>[];

    for (int index = 0; index < rawLayers.length; index++) {
      final Map<String, Object?> layerJson = Map<String, Object?>.from(
        rawLayers[index]! as Map,
      );

      final String? sourcePath = layerJson['imagePath'] as String?;

      if (sourcePath != null && sourcePath.isNotEmpty) {
        final File sourceFile = File(sourcePath);

        if (await sourceFile.exists()) {
          final String layerId = (layerJson['id'] as String? ?? 'layer_$index')
              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');

          final String extension = _fileExtension(sourcePath);

          final File savedImage = File(
            '${assetsDirectory.path}/${index}_$layerId$extension',
          );

          if (sourceFile.absolute.path != savedImage.absolute.path) {
            await sourceFile.copy(savedImage.path);
          }

          layerJson['imagePath'] = savedImage.path;
        }
      }

      final String? cutoutOriginalPath =
          layerJson['cutoutOriginalPath'] as String?;

      if (cutoutOriginalPath != null && cutoutOriginalPath.isNotEmpty) {
        final File originalFile = File(cutoutOriginalPath);

        if (await originalFile.exists()) {
          final String layerId = (layerJson['id'] as String? ?? 'layer_$index')
              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');

          final String extension = _fileExtension(cutoutOriginalPath);

          final File savedOriginal = File(
            '${assetsDirectory.path}/'
            '${index}_${layerId}_cutout_original$extension',
          );

          if (originalFile.absolute.path != savedOriginal.absolute.path) {
            await originalFile.copy(savedOriginal.path);
          }

          layerJson['cutoutOriginalPath'] = savedOriginal.path;
        }
      }

      savedLayers.add(layerJson);
    }

    projectJson['layers'] = savedLayers;

    final String jsonText = const JsonEncoder.withIndent(
      '  ',
    ).convert(projectJson);

    await projectFile.writeAsString(jsonText, flush: true);

    return projectFile;
  }

  String _fileExtension(String filePath) {
    final String fileName = filePath.split('/').last;
    final int dotIndex = fileName.lastIndexOf('.');

    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return '.png';
    }

    final String extension = fileName.substring(dotIndex).toLowerCase();

    if (extension.length > 10) {
      return '.png';
    }

    return extension;
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
    final String fileName = file.path.split('/').last;
    final String projectFolderName = fileName.endsWith('.photoforge')
        ? fileName.substring(0, fileName.length - '.photoforge'.length)
        : fileName;

    final Directory directory = await projectsDirectory;

    final Directory assetsDirectory = Directory(
      '${directory.path}/assets/$projectFolderName',
    );

    if (await file.exists()) {
      await file.delete();
    }

    if (await assetsDirectory.exists()) {
      await assetsDirectory.delete(recursive: true);
    }
  }
}
