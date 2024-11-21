import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class CreateRoomScreen extends StatefulWidget {
  final String loggedInUserEmail;
  final String loggedInUserName;

  CreateRoomScreen({
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  });
  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _gameNameController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _selectedPlayerSlots = 2; // Default is 2
  int _selectedWaitlistSlots = 0; // Default is 0

  // Handle room creation
  void _handleCreateRoom() async {
    final gameName = _gameNameController.text.trim();
    final address = _addressController.text.trim();
    final selectedDate = _selectedDate;
    final selectedTime = _selectedTime;

    // Validate required fields
    if (gameName.isEmpty ||
        selectedDate == null ||
        selectedTime == null ||
        address.isEmpty) {
      _showErrorDialog('Por favor, preencha todos os campos obrigatórios.');
      return;
    }

    // Combine date and time into a full DateTime for storage
    final DateTime fullDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final room = {
      'gameName': gameName,
      'dateTime': fullDateTime.toIso8601String(),
      'address': address,
      'playerSlots': _selectedPlayerSlots,
      'waitlistSlots': _selectedWaitlistSlots,
      'creatorName': widget.loggedInUserName,
    };

    try {
      // Insert the room into the database
      final roomId = await DatabaseHelper.instance.insertRoom(room);

      // Add the creator as a participant
      int userId = await _getLoggedInUserId();
      await DatabaseHelper.instance.addParticipant(roomId, userId);

      // Show a confirmation dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Sala Criada'),
            content: Text(
                'A sala "$gameName" foi criada com sucesso para ${fullDateTime.day}/${fullDateTime.month}/${fullDateTime.year} às ${fullDateTime.hour}:${fullDateTime.minute.toString().padLeft(2, '0')}.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Return to the previous screen
                },
                child: Text('Ok'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showErrorDialog('Erro ao criar a sala. Tente novamente.');
    }
  }

  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  // Show an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Erro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  // Methods to pick date and time
  Future<void> _pickDate(BuildContext context) async {
    final currentDate = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: currentDate,
      lastDate: DateTime(currentDate.year + 2),
      helpText: 'Selecione a data do jogo',
      cancelText: 'Cancelar',
      confirmText: 'Ok',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay initialTime = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Selecione o horário do jogo',
      cancelText: 'Cancelar',
      confirmText: 'Ok',
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Dispose controllers to free resources
  @override
  void dispose() {
    _gameNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Build the UI for the Create Room screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Criar Sala'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Name Field
            TextFormField(
              controller: _gameNameController,
              decoration:
                  InputDecoration(labelText: 'Nome do jogo (máx. 32 caracteres)'),
              maxLength: 32,
            ),
            SizedBox(height: 16),

            // Date selection
            Row(
              children: [
                Expanded(
                  child: Text(_selectedDate == null
                      ? 'Nenhuma data selecionada'
                      : 'Data: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _pickDate(context);
                  },
                  child: Text('Selecione a data'),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Time selection
            Row(
              children: [
                Expanded(
                  child: Text(_selectedTime == null
                      ? 'Nenhum horário selecionado'
                      : 'Horário: ${_selectedTime!.format(context)}'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _pickTime(context);
                  },
                  child: Text('Selecione o horário'),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Address Field
            TextFormField(
              controller: _addressController,
              decoration:
                  InputDecoration(labelText: 'Endereço (máx. 64 caracteres)'),
              maxLength: 64,
            ),
            SizedBox(height: 16),

            // Number of player slots
            DropdownButtonFormField<int>(
              value: _selectedPlayerSlots,
              decoration:
                  InputDecoration(labelText: 'Número de vagas de jogadores'),
              items: List.generate(
                9,
                (index) => DropdownMenuItem(
                    value: index + 2, child: Text('${index + 2} jogadores')),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedPlayerSlots = value!;
                });
              },
            ),
            SizedBox(height: 16),

            // Number of waitlist slots
            DropdownButtonFormField<int>(
              value: _selectedWaitlistSlots,
              decoration:
                  InputDecoration(labelText: 'Número de vagas na lista de espera'),
              items: List.generate(
                6,
                (index) => DropdownMenuItem(
                    value: index, child: Text('$index vagas')),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedWaitlistSlots = value!;
                });
              },
            ),
            SizedBox(height: 16),

            // Room creator (automatically filled)
            Text(
              'Autor da sala: ${widget.loggedInUserName}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            // Spacing
            SizedBox(height: 32),

            // Buttons (Criar and Voltar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _handleCreateRoom,
                  child: Text('Criar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Voltar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
