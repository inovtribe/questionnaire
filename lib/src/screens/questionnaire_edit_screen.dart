import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:questionnaire/src/blocs/providers/user_provider.dart';
import 'package:questionnaire/src/helper/firebase.dart';
import 'package:questionnaire/src/helper/focus.dart';
import 'package:questionnaire/src/helper/image_picker.dart';
import 'package:questionnaire/src/helper/position.dart';
import 'package:questionnaire/src/screens/base/base_modal_screen_state.dart';
import 'package:questionnaire/src/widgets/input_dialog.dart';
import '../mixins/common_fields.dart';

class QuestionnaireEditScreen extends StatefulWidget {
  @override
  _QuestionnaireEditScreenState createState() =>
      _QuestionnaireEditScreenState();
}

class _QuestionnaireEditScreenState extends BaseModalScreenState
    with CommonFields {
  var questionPanelsData = <_PanelData>[];
  var resultPanelsData = <_PanelData>[];

  final imageButtonKey = GlobalKey();

  Future<Image> futureImage;

  File previousImageFile;
  ImageSource previousImageSource;

  var isNameValid = true;
  var isAboutValid = true;

  final nameController = TextEditingController();
  final aboutController = TextEditingController();

  @override
  Widget buildBody() {
    return SingleChildScrollView(
      child: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            buildNameTextField(
              nameController,
              isNameValid,
              (isValid) {
                isNameValid = isValid;
              },
            ),
            buildAboutTextField(
              aboutController,
              isAboutValid,
              (isValid) {
                isAboutValid = isValid;
              },
            ),
            buildImageTitle(),
            buildImageView(),
            buildPanelListTitle(questionPanelsData, _PanelType.question),
            buildPanelList(questionPanelsData, _PanelType.question),
            buildPanelListTitle(resultPanelsData, _PanelType.result),
            buildPanelList(resultPanelsData, _PanelType.result),
          ],
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Widget buildImageTitle() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 21),
      child: Stack(
        overflow: Overflow.visible,
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          Positioned(
            child: previousImageFile != null
                ? buildEditButton(onImageAddButtonPressed)
                : buildAddButton(
                    onImageAddButtonPressed,
                    isImageButton: true,
                  ),
            right: 0,
          ),
          Text(
            'Image',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  void Function() onPanelAddButtonPressed(
      List<_PanelData> panelsData, _PanelType type) {
    return () async {
      final input = await showInputDialog(context, 'Add ${type.name}',
          panelsData.map((panelData) => panelData.title).toList());
      if (input == null) return;
      setState(() {
        panelsData.forEach((panelData) =>
            panelData.isExpanded = false); //temporarily fixing bug #13780
        panelsData.add(_PanelData(input, type));
      });
    };
  }

  void onImageAddButtonPressed() async {
    final imageAction = await pickPopupMenuAction(
      [_PopupMenuAction.gallery, _PopupMenuAction.camera] +
          (previousImageFile != null ? [_PopupMenuAction.delete] : []),
    );

    if (imageAction == null) return;

    if (imageAction.imageSource == null) {
      disposeCameraImage();
      setState(() {
        previousImageFile = null;
      });
      previousImageSource = null;
      futureImage = Future.error('image deleted');
    } else {
      futureImage = pickImage(imageAction.imageSource);
    }
  }

  Future<_PopupMenuAction> pickPopupMenuAction(List<_PopupMenuAction> actions) {
    var items = List<PopupMenuEntry<_PopupMenuAction>>();

    for (final action in actions) {
      switch (action) {
        case _PopupMenuAction.camera:
          items.add(
            PopupMenuItem(
              value: _PopupMenuAction.camera,
              child: ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Camera'),
              ),
            ),
          );
          break;
        case _PopupMenuAction.gallery:
          items.add(
            PopupMenuItem(
              value: _PopupMenuAction.gallery,
              child: ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
              ),
            ),
          );
          break;
        case _PopupMenuAction.delete:
          items += <PopupMenuEntry<_PopupMenuAction>>[
            PopupMenuDivider(),
            PopupMenuItem(
              value: _PopupMenuAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
              ),
            ),
          ];
          break;
      }
    }

    return showMenu<_PopupMenuAction>(
      context: context,
      position: getPosition(imageButtonKey),
      items: items,
    );
  }

  void disposeCameraImage() {
    if (previousImageSource == ImageSource.camera) {
      previousImageFile?.delete();
    }
  }

  Future<Image> pickImage(ImageSource source) async {
    var imageFile = await pickImageFrom(source);

    if (imageFile != null) {
      disposeCameraImage();
      previousImageSource = source;
      setState(() {
        previousImageFile = imageFile;
      });
    } else {
      imageFile = previousImageFile;
    }

    return Image.file(imageFile);
  }

  Widget buildAddButton(void Function() onPressed,
      {bool isImageButton = false}) {
    return RaisedButton.icon(
      key: isImageButton ? imageButtonKey : null,
      color: Colors.blue,
      textColor: Colors.white,
      icon: Icon(Icons.add),
      label: Text('Add'),
      onPressed: () {
        clearFocus(context);
        onPressed();
      },
    );
  }

  Widget buildEditButton(void Function() onPressed) {
    return RaisedButton.icon(
      key: imageButtonKey,
      color: Colors.blue,
      textColor: Colors.white,
      icon: Icon(Icons.edit),
      label: Text('Edit'),
      onPressed: () {
        clearFocus(context);
        onPressed();
      },
    );
  }

  Widget buildImageView() {
    return FutureBuilder<Image>(
      future: futureImage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == null) {
          return Center(
            child: buildPanelBodyPlaceholder('Image will appear here.'),
          );
        }

        return Center(
          child: Card(
            elevation: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                child: snapshot.data,
                height: 100,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildPanelListTitle(List<_PanelData> panelsData, _PanelType type) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 21),
      child: Stack(
        overflow: Overflow.visible,
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          Positioned(
            child: buildAddButton(
              onPanelAddButtonPressed(panelsData, type),
            ),
            right: 0,
          ),
          Text(
            '${type.name}s',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget buildPanelBodyPlaceholder(String purpose) {
    return Text(
      purpose,
      style: TextStyle(color: Colors.grey),
    );
  }

  Widget buildPanelActionButton(_PanelAction action, _PanelData panelData,
      _PanelType type, List<_PanelData> panelsData) {
    String text;
    void Function() onPressed;
    Color color = Colors.blue;

    switch (action) {
      case _PanelAction.add:
        text = 'ADD';
        onPressed = () async {
          final alternative = await showInputDialog(
            context,
            'Add Alternative',
            panelData.alternatives
                .map((alternative) => alternative.name)
                .toList(),
          );
          if (alternative == null) return;
          setState(() {
            panelData.alternatives.add(_Alternative(alternative));
          });
        };
        break;
      case _PanelAction.edit:
        text = 'EDIT';
        onPressed = () async {
          final title = await showInputDialog(
            context,
            'Edit ${type.name}',
            panelsData.map((panelData) => panelData.title).toList(),
            panelData.title,
          );
          if (title == null) return;
          setState(() {
            panelData.title = title;
          });
        };
        break;
      case _PanelAction.delete:
        text = 'DELETE';
        color = Colors.red;
        onPressed = () {
          setState(() {
            panelsData.remove(panelData);
          });
        };
        break;
    }

    return FlatButton(
      child: Text(
        text,
        style: TextStyle(color: color),
      ),
      onPressed: () {
        clearFocus(context);
        onPressed();
      },
    );
  }

  List<Widget> buildWrapQuestionChildren(_PanelData panelData) {
    return panelData.alternatives.map(
      (alternative) {
        return Chip(
          label: Text(alternative.name),
          backgroundColor: alternative.color,
          onDeleted: () {
            setState(() {
              panelData.alternatives.remove(alternative);
            });
          },
        );
      },
    ).toList();
  }

  List<Widget> buildWrapResultChildren(
      _PanelData questionPanelData, _PanelData resultPanelData) {
    return questionPanelData.alternatives.map((alternative) {
      return InputChip(
        selected: alternative.selectedIn.contains(resultPanelData),
        label: Text(alternative.name),
        selectedColor: alternative.color,
        onSelected: (isSelected) {
          setState(() {
            if (isSelected) {
              alternative.selectedIn.add(resultPanelData);
            } else {
              alternative.selectedIn.remove(resultPanelData);
            }
          });
        },
      );
    }).toList();
  }

  List<Widget> buildWrapsResultList(_PanelData panelData) {
    return questionPanelsData
        .map(
          (questionPanelData) {
            return [
              SizedBox(height: 8),
              Text(questionPanelData.title),
              SizedBox(height: 8),
              questionPanelData.alternatives.isNotEmpty
                  ? buildWrappedChips(
                      questionPanelData, _PanelType.result, panelData)
                  : buildPanelBodyPlaceholder('Alternatives will appear here.'),
              SizedBox(height: 8),
              Divider(height: 0),
            ];
          },
        )
        .expand((list) => list)
        .toList();
  }

  //pass resultPanelData if panel type == result
  Widget buildWrappedChips(_PanelData questionPanelData, _PanelType type,
      [_PanelData resultPanelData]) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: -8,
        children: type == _PanelType.question
            ? buildWrapQuestionChildren(questionPanelData)
            : buildWrapResultChildren(questionPanelData, resultPanelData),
      ),
    );
  }

  Widget buildButtonBar(_PanelData panelData, List<_PanelAction> actions,
      _PanelType type, List<_PanelData> panelsData) {
    final children = actions.map(
      (action) {
        return buildPanelActionButton(action, panelData, type, panelsData);
      },
    ).toList();

    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: children,
      ),
      margin: EdgeInsets.only(right: 8),
    );
  }

  Widget buildPanelBody(_PanelData panelData) {
    switch (panelData.type) {
      case _PanelType.question:
        return Column(
          children: <Widget>[
            panelData.alternatives.isEmpty
                ? buildPanelBodyPlaceholder('Alternatives will appear here.')
                : buildWrappedChips(panelData, _PanelType.question),
            SizedBox(height: 8),
            Divider(height: 0),
            buildButtonBar(
                panelData,
                [_PanelAction.delete, _PanelAction.edit, _PanelAction.add],
                _PanelType.question,
                questionPanelsData),
          ],
        );
      case _PanelType.result:
        var children = buildWrapsResultList(panelData);
        if (questionPanelsData.isEmpty) {
          children += [
            buildPanelBodyPlaceholder('Firstly add some questions.'),
            SizedBox(height: 8),
            Divider(height: 0),
          ];
        }
        children.add(
          buildButtonBar(panelData, [_PanelAction.delete, _PanelAction.edit],
              _PanelType.result, resultPanelsData),
        );
        return Column(children: children);
      default:
        throw Exception('_PanelType enum exhausted.');
    }
  }

  ExpansionPanel buildPanel(_PanelData panelData) {
    return ExpansionPanel(
      body: buildPanelBody(panelData),
      headerBuilder: (context, isExpanded) {
        String subtitle;
        if (panelData.type == _PanelType.question) {
          subtitle = '${panelData.alternatives.length} alternatives';
        } else {
          final selectedAlternatives = questionPanelsData.map(
            (questionPanelData) {
              return questionPanelData.alternatives.where(
                (alternative) {
                  return alternative.selectedIn.contains(panelData);
                },
              ).length;
            },
          ).fold(
            0,
            (sum, length) {
              return sum + length;
            },
          );
          subtitle = '$selectedAlternatives selected';
        }
        return buildPanelHeader(panelData.title, subtitle, isExpanded);
      },
      isExpanded: panelData.isExpanded,
    );
  }

  Widget buildPanelList(List<_PanelData> panelsData, _PanelType type) {
    if (panelsData.isEmpty) {
      return Text(
        '${type.name}s will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      );
    }

    var panels = List<ExpansionPanel>();
    for (final panelData in panelsData) {
      panels.add(buildPanel(panelData));
    }

    return ExpansionPanelList(
      expansionCallback: (index, isExpanded) {
        setState(() {
          panelsData[index].isExpanded = !isExpanded;
        });
      },
      children: panels,
    );
  }

  Widget buildPanelHeader(String title, String subtitle, bool isExpanded) {
    return ListTile(
      title: Text(title),
      subtitle: isExpanded
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
    );
  }

  @override
  bool get isSaveEnabled =>
      isNameValid &&
      isAboutValid &&
      nameController.text.isNotEmpty &&
      questionPanelsData.isNotEmpty &&
      questionPanelsData.every(
        (panelData) {
          return panelData.alternatives.isNotEmpty;
        },
      ) &&
      resultPanelsData.isNotEmpty &&
      questionPanelsData.every(
        (panelData) {
          return panelData.alternatives.every(
            (alternative) {
              return alternative.selectedIn.isNotEmpty;
            },
          );
        },
      );

  @override
  Future<void> onSavePressed() async {
    final name = getTrimmedText(nameController);
    final about = getTrimmedText(aboutController);

    final questions = questionPanelsData.fold<Map<String, List<_Alternative>>>(
      {},
      (acc, panelData) {
        acc[panelData.title] = panelData.alternatives;
        return acc;
      },
    );
    final results =
        resultPanelsData.fold<Map<String, Map<String, List<String>>>>(
      {},
      (acc, panelData) {
        final selectedInQuestion = questions.map<String, List<String>>(
          (name, alternatives) {
            final selected = alternatives
                .where(
                  (alternative) {
                    return alternative.selectedIn.contains(panelData);
                  },
                )
                .map((alternative) => alternative.name)
                .toList();

            return MapEntry(name, selected);
          },
        );

        acc[panelData.title] = selectedInQuestion;
        return acc;
      },
    );
    final mappedQuestions = questions.map(
      (name, alternatives) {
        final alternativeNames =
            alternatives.map((alternative) => alternative.name).toList();
        return MapEntry(name, alternativeNames);
      },
    );

    final bloc = UserProvider.of(context);
    final userUid = bloc.lastUser(UserType.primary).uid;
    final userDocument = Firestore.instance.document('users/$userUid');

    final questionnaireDocument =
        await Firestore.instance.collection('questionnaires').add({
      'name': name,
      'about': about,
      'questions': mappedQuestions,
      'results': results,
      'since': FieldValue.serverTimestamp(),
      'creator': userDocument,
    });

    if (previousImageFile != null) {
      final photoName = questionnaireDocument.documentID;
      final photoUrl = await uploadFile(previousImageFile, photoName);
      questionnaireDocument.updateData({'photoUrl': photoUrl});
    }
  }

  @override
  String get title => 'Add Questionnaire';

  @override
  void dispose() {
    super.dispose();

    disposeCameraImage();
  }
}

class _PanelData {
  _PanelType type;
  String title;
  var isExpanded = false;
  List<_Alternative> alternatives;

  _PanelData(this.title, this.type) {
    if (type == _PanelType.question) {
      alternatives = <_Alternative>[];
    }
  }
}

class _Alternative {
  String name;
  Color color;
  var selectedIn = Set<_PanelData>();

  _Alternative(this.name) {
    final random = Random().nextInt(Colors.primaries.length);
    color = Colors.primaries[random][200];
  }
}

enum _PanelAction { add, edit, delete }

class _PanelType {
  static const question = _PanelType._('Question');
  static const result = _PanelType._('Result');

  final String name;

  const _PanelType._(this.name);
}

class _PopupMenuAction {
  static const camera = _PopupMenuAction(ImageSource.camera);
  static const gallery = _PopupMenuAction(ImageSource.gallery);
  static const delete = _PopupMenuAction(null);

  final ImageSource imageSource;

  const _PopupMenuAction(this.imageSource);
}
