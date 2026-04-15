package com.pitwall.app.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitwall.app.data.remote.model.UpdateProfileRequest
import com.pitwall.app.ui.components.LoadingIndicator
import com.pitwall.app.ui.theme.*
import com.pitwall.app.util.formatMemberSince

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    onLogout: () -> Unit,
    viewModel: ProfileViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    var showEditDriver by remember { mutableStateOf(false) }
    var showEditTeam by remember { mutableStateOf(false) }
    var showLanguage by remember { mutableStateOf(false) }
    var showUpdateDetails by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitwallBackground),
    ) {
        if (uiState.isLoading && uiState.user == null) {
            LoadingIndicator()
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                // Header
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .statusBarsPadding()
                        .padding(horizontal = 16.dp, vertical = 16.dp),
                ) {
                    Text("Profile", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(16.dp))

                    val user = uiState.user
                    if (user != null) {
                        Text(user.username, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                        Text(user.email, color = PitwallSecondaryText, fontSize = 14.sp)
                        if (user.createdAt != null) {
                            Text(
                                "Member since ${formatMemberSince(user.createdAt)}",
                                color = PitwallTertiaryText,
                                fontSize = 12.sp,
                            )
                        }
                    }
                }

                // F1 Preferences section
                SectionHeader("F1 Preferences")
                PreferenceRow(
                    icon = Icons.Default.Person,
                    label = "Favourite Driver",
                    value = uiState.user?.favDriver ?: "Not set",
                    onClick = { showEditDriver = true },
                )
                PreferenceRow(
                    icon = Icons.Default.Groups,
                    label = "Favourite Team",
                    value = uiState.user?.favTeam ?: "Not set",
                    onClick = { showEditTeam = true },
                )
                PreferenceRow(
                    icon = Icons.Default.Language,
                    label = "AI Language",
                    value = when (uiState.user?.language) {
                        "es" -> "Espanol"
                        "zh" -> "Chinese"
                        else -> "English"
                    },
                    onClick = { showLanguage = true },
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Account section
                SectionHeader("Account")
                PreferenceRow(
                    icon = Icons.Default.Edit,
                    label = "Update Details",
                    value = "",
                    onClick = { showUpdateDetails = true },
                )
                PreferenceRow(
                    icon = Icons.AutoMirrored.Filled.ExitToApp,
                    label = "Log Out",
                    value = "",
                    onClick = {
                        viewModel.logout()
                        onLogout()
                    },
                    tint = PitwallRed,
                )
                PreferenceRow(
                    icon = Icons.Default.DeleteForever,
                    label = "Delete Account",
                    value = "",
                    onClick = { showDeleteConfirm = true },
                    tint = Color(0xFFCF6679),
                )

                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }

    // Edit driver sheet
    if (showEditDriver) {
        EditPreferenceSheet(
            title = "Favourite Driver",
            currentValue = uiState.user?.favDriver ?: "",
            onSave = { value ->
                viewModel.updateProfile(UpdateProfileRequest(favDriver = value))
                showEditDriver = false
            },
            onDismiss = { showEditDriver = false },
        )
    }

    // Edit team sheet
    if (showEditTeam) {
        EditPreferenceSheet(
            title = "Favourite Team",
            currentValue = uiState.user?.favTeam ?: "",
            onSave = { value ->
                viewModel.updateProfile(UpdateProfileRequest(favTeam = value))
                showEditTeam = false
            },
            onDismiss = { showEditTeam = false },
        )
    }

    // Language picker
    if (showLanguage) {
        LanguagePickerSheet(
            currentLanguage = uiState.user?.language ?: "en",
            onSelect = { code ->
                viewModel.updateProfile(UpdateProfileRequest(language = code))
                showLanguage = false
            },
            onDismiss = { showLanguage = false },
        )
    }

    // Update details sheet
    if (showUpdateDetails) {
        UpdateDetailsSheet(
            user = uiState.user,
            onSave = { request ->
                viewModel.updateProfile(request)
                showUpdateDetails = false
            },
            onDismiss = { showUpdateDetails = false },
        )
    }

    // Delete confirmation
    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("Delete Account", color = Color.White) },
            text = { Text("This action cannot be undone. All your data will be permanently deleted.", color = PitwallSecondaryText) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteAccount()
                    showDeleteConfirm = false
                    onLogout()
                }) {
                    Text("Delete", color = Color(0xFFCF6679))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text("Cancel", color = PitwallSecondaryText)
                }
            },
            containerColor = PitwallCard,
        )
    }
}

@Composable
fun SectionHeader(title: String) {
    Text(
        text = title,
        color = PitwallSecondaryText,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
fun PreferenceRow(
    icon: ImageVector,
    label: String,
    value: String,
    onClick: () -> Unit,
    tint: Color = Color.White,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.width(12.dp))
        Text(label, color = tint, fontSize = 15.sp, modifier = Modifier.weight(1f))
        if (value.isNotEmpty()) {
            Text(value, color = PitwallTertiaryText, fontSize = 13.sp)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditPreferenceSheet(
    title: String,
    currentValue: String,
    onSave: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var value by remember { mutableStateOf(currentValue) }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = PitwallCard) {
        Column(modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 32.dp)) {
            Text(title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(16.dp))
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = PitwallRed, unfocusedBorderColor = PitwallTertiaryText,
                    cursorColor = PitwallRed, focusedTextColor = Color.White, unfocusedTextColor = Color.White,
                ),
                shape = RoundedCornerShape(10.dp),
            )
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = { onSave(value) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = PitwallRed),
                shape = RoundedCornerShape(10.dp),
            ) {
                Text("Save")
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LanguagePickerSheet(
    currentLanguage: String,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val languages = listOf("en" to "English", "es" to "Espanol", "zh" to "Chinese")

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = PitwallCard) {
        Column(modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 32.dp)) {
            Text("AI Response Language", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(16.dp))
            languages.forEach { (code, name) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(code) }
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(
                        selected = currentLanguage == code,
                        onClick = { onSelect(code) },
                        colors = RadioButtonDefaults.colors(selectedColor = PitwallRed),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(name, color = Color.White, fontSize = 15.sp)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpdateDetailsSheet(
    user: com.pitwall.app.data.remote.model.UserOut?,
    onSave: (UpdateProfileRequest) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf(user?.name ?: "") }
    var email by remember { mutableStateOf(user?.email ?: "") }
    var newPassword by remember { mutableStateOf("") }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = PitwallCard) {
        Column(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
        ) {
            Text("Update Details", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(16.dp))

            val tfColors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PitwallRed, unfocusedBorderColor = PitwallTertiaryText,
                cursorColor = PitwallRed, focusedTextColor = Color.White, unfocusedTextColor = Color.White,
            )
            val tfShape = RoundedCornerShape(10.dp)

            OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") },
                singleLine = true, modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape)
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Email") },
                singleLine = true, modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape)
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(value = newPassword, onValueChange = { newPassword = it }, label = { Text("New Password (optional)") },
                singleLine = true, modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape)
            Spacer(modifier = Modifier.height(20.dp))

            Button(
                onClick = {
                    onSave(UpdateProfileRequest(
                        name = name.ifBlank { null },
                        email = email.ifBlank { null },
                        password = newPassword.ifBlank { null },
                    ))
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = PitwallRed),
                shape = RoundedCornerShape(10.dp),
            ) {
                Text("Save Changes")
            }
        }
    }
}
