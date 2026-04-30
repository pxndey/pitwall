package com.pitcrew.app.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitcrew.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignUpScreen(
    onSignUpSuccess: () -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    var username by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var selectedDriverId by remember { mutableStateOf<String?>(null) }
    var selectedTeamId by remember { mutableStateOf<String?>(null) }
    var driverExpanded by remember { mutableStateOf(false) }
    var teamExpanded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { viewModel.loadF1Data() }

    LaunchedEffect(uiState.isSuccess) {
        if (uiState.isSuccess) {
            viewModel.resetSuccess()
            onSignUpSuccess()
        }
    }

    val passwordMismatch = confirmPassword.isNotEmpty() && password != confirmPassword

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitCrewBackground),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(top = 60.dp, bottom = 32.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onNavigateBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Spacer(modifier = Modifier.width(8.dp))
                Text("Create Account", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            }

            Spacer(modifier = Modifier.height(32.dp))

            val tfColors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PitCrewRed,
                unfocusedBorderColor = PitCrewTertiaryText,
                focusedLabelColor = PitCrewRed,
                cursorColor = PitCrewRed,
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
            )
            val tfShape = RoundedCornerShape(10.dp)

            OutlinedTextField(
                value = username, onValueChange = { username = it },
                label = { Text("Username") }, singleLine = true,
                modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape,
            )
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = fullName, onValueChange = { fullName = it },
                label = { Text("Full Name") }, singleLine = true,
                modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape,
            )
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = email, onValueChange = { email = it },
                label = { Text("Email") }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape,
            )
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = password, onValueChange = { password = it },
                label = { Text("Password") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape,
            )
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = confirmPassword, onValueChange = { confirmPassword = it },
                label = { Text("Confirm Password") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                isError = passwordMismatch,
                modifier = Modifier.fillMaxWidth(), colors = tfColors, shape = tfShape,
            )
            if (passwordMismatch) {
                Text("Passwords do not match", color = PitCrewRed, fontSize = 12.sp,
                    modifier = Modifier.padding(start = 4.dp, top = 4.dp))
            }

            Spacer(modifier = Modifier.height(20.dp))
            Text("F1 Preferences (optional)", color = PitCrewSecondaryText, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(12.dp))

            // Driver dropdown
            ExposedDropdownMenuBox(
                expanded = driverExpanded,
                onExpandedChange = { driverExpanded = it },
            ) {
                OutlinedTextField(
                    value = uiState.drivers.find { it.driverId == selectedDriverId }?.let { "${it.givenName} ${it.familyName}" } ?: "",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Favourite Driver") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = driverExpanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(),
                    colors = tfColors, shape = tfShape,
                )
                ExposedDropdownMenu(
                    expanded = driverExpanded,
                    onDismissRequest = { driverExpanded = false },
                    modifier = Modifier.background(PitCrewCard),
                ) {
                    uiState.drivers.forEach { driver ->
                        DropdownMenuItem(
                            text = { Text("${driver.givenName} ${driver.familyName}", color = Color.White) },
                            onClick = {
                                selectedDriverId = driver.driverId
                                driverExpanded = false
                            },
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Team dropdown
            ExposedDropdownMenuBox(
                expanded = teamExpanded,
                onExpandedChange = { teamExpanded = it },
            ) {
                OutlinedTextField(
                    value = uiState.constructors.find { it.constructorId == selectedTeamId }?.name ?: "",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Favourite Team") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = teamExpanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(),
                    colors = tfColors, shape = tfShape,
                )
                ExposedDropdownMenu(
                    expanded = teamExpanded,
                    onDismissRequest = { teamExpanded = false },
                    modifier = Modifier.background(PitCrewCard),
                ) {
                    uiState.constructors.forEach { team ->
                        DropdownMenuItem(
                            text = { Text(team.name ?: "", color = Color.White) },
                            onClick = {
                                selectedTeamId = team.constructorId
                                teamExpanded = false
                            },
                        )
                    }
                }
            }

            if (uiState.errorMessage != null) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(text = uiState.errorMessage!!, color = PitCrewRed, fontSize = 13.sp)
            }

            Spacer(modifier = Modifier.height(24.dp))

            val canSubmit = username.isNotBlank() && email.isNotBlank() &&
                password.isNotBlank() && password == confirmPassword && !uiState.isLoading

            Button(
                onClick = { viewModel.signup(username, fullName, email, password, selectedDriverId, selectedTeamId) },
                enabled = canSubmit,
                modifier = Modifier.fillMaxWidth().height(50.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PitCrewRed),
                shape = RoundedCornerShape(10.dp),
            ) {
                if (uiState.isLoading) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
                } else {
                    Text("Create Account", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
            ) {
                Text("Already have an account? ", color = PitCrewSecondaryText, fontSize = 14.sp)
                Text("Sign In", color = PitCrewRed, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable { onNavigateBack() })
            }
        }
    }
}
