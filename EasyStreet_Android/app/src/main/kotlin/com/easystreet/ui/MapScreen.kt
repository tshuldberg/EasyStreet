package com.easystreet.ui

import android.Manifest
import android.content.pm.PackageManager
import android.location.Geocoder
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.easystreet.domain.engine.HolidayCalculator
import com.easystreet.domain.engine.SweepingRuleEngine
import com.easystreet.domain.model.StreetSegment
import com.easystreet.domain.model.SweepingStatus
import com.google.android.gms.location.LocationServices
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(viewModel: MapViewModel = viewModel()) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // SF default location
    val sfCenter = LatLng(37.7749, -122.4194)
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(sfCenter, 15f)
    }

    val visibleSegments by viewModel.visibleSegments.collectAsState()
    val parkedCar by viewModel.parkingRepo.parkedCar.collectAsState()
    val sweepingStatus by viewModel.sweepingStatus.collectAsState()
    val dbError by viewModel.dbError.collectAsState()

    var searchQuery by remember { mutableStateOf("") }
    var showSearch by remember { mutableStateOf(false) }
    val selectedSegment by viewModel.selectedSegment.collectAsState()

    // Disclaimer state
    var showDisclaimer by remember { mutableStateOf(!DisclaimerManager.hasSeenDisclaimer(context)) }

    // Notification settings state
    var showNotificationSettings by remember { mutableStateOf(false) }

    // Location permission
    val hasLocationPermission = remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        hasLocationPermission.value = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true
    }

    // Notification permission launcher (API 33+)
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { _ ->
        // Permission result doesn't block parking — notification just won't fire if denied
    }

    LaunchedEffect(Unit) {
        if (!hasLocationPermission.value) {
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                )
            )
        }
    }

    // Move to user location on first permission grant
    LaunchedEffect(hasLocationPermission.value) {
        if (hasLocationPermission.value) {
            val fusedClient = LocationServices.getFusedLocationProviderClient(context)
            try {
                fusedClient.lastLocation.addOnSuccessListener { location ->
                    if (location != null) {
                        scope.launch {
                            cameraPositionState.animate(
                                CameraUpdateFactory.newLatLngZoom(
                                    LatLng(location.latitude, location.longitude),
                                    16f,
                                )
                            )
                        }
                    }
                }
            } catch (_: SecurityException) {
                // Permission was revoked between check and use
            }
        }
    }

    // Viewport change listener
    val isMoving = cameraPositionState.isMoving
    LaunchedEffect(isMoving) {
        if (!isMoving) {
            val bounds = cameraPositionState.projection?.visibleRegion?.latLngBounds ?: return@LaunchedEffect
            viewModel.onViewportChanged(
                bounds.southwest.latitude,
                bounds.northeast.latitude,
                bounds.southwest.longitude,
                bounds.northeast.longitude,
            )
        }
    }

    // Disclaimer dialog
    if (showDisclaimer) {
        AlertDialog(
            onDismissRequest = { /* Require explicit dismissal */ },
            title = { Text(DisclaimerManager.DISCLAIMER_TITLE) },
            text = { Text(DisclaimerManager.DISCLAIMER_BODY) },
            confirmButton = {
                TextButton(onClick = {
                    DisclaimerManager.markDisclaimerSeen(context)
                    showDisclaimer = false
                }) {
                    Text("I Understand")
                }
            },
        )
    }

    // Notification settings dialog
    if (showNotificationSettings) {
        NotificationSettingsDialog(
            currentLeadMinutes = viewModel.notificationLeadMinutes,
            onDismiss = { showNotificationSettings = false },
            onSelected = { minutes ->
                viewModel.updateNotificationLeadMinutes(minutes)
                showNotificationSettings = false
            },
        )
    }

    Box(modifier = Modifier.fillMaxSize()) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            properties = MapProperties(
                isMyLocationEnabled = hasLocationPermission.value,
            ),
            uiSettings = MapUiSettings(
                myLocationButtonEnabled = hasLocationPermission.value,
                zoomControlsEnabled = false,
            ),
        ) {
            // Street overlays with day-offset color system
            val today = LocalDate.now()
            visibleSegments.forEach { segment ->
                val color = mapColorForSegment(segment, today)

                Polyline(
                    points = segment.coordinates.map { LatLng(it.latitude, it.longitude) },
                    color = color.copy(alpha = 0.85f),
                    width = 8f,
                    clickable = true,
                    zIndex = 1f,
                    onClick = { viewModel.onStreetTapped(segment) },
                )
            }

            // Parked car marker with drag support
            parkedCar?.let { car ->
                val markerState = rememberMarkerState(position = LatLng(car.latitude, car.longitude))

                LaunchedEffect(car.latitude, car.longitude) {
                    markerState.position = LatLng(car.latitude, car.longitude)
                }

                // Observe drag state changes to handle drag end
                LaunchedEffect(markerState.dragState) {
                    if (markerState.dragState == DragState.END) {
                        viewModel.updateParkingLocation(
                            markerState.position.latitude,
                            markerState.position.longitude,
                        )
                    }
                }

                MarkerInfoWindow(
                    state = markerState,
                    title = car.streetName,
                    snippet = "Drag to adjust",
                    icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE),
                    draggable = true,
                )
            }
        }

        // Top-left: Info icon to re-show disclaimer
        IconButton(
            onClick = { showDisclaimer = true },
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(16.dp),
        ) {
            Icon(
                Icons.Default.Info,
                contentDescription = "Show disclaimer",
                tint = MaterialTheme.colorScheme.onSurface,
            )
        }

        // Search bar / search icon (top-right)
        if (showSearch) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .align(Alignment.TopCenter),
                placeholder = { Text("Search address...") },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surface,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                ),
                trailingIcon = {
                    TextButton(onClick = {
                        scope.launch {
                            searchAddress(context, searchQuery, cameraPositionState)
                            showSearch = false
                            searchQuery = ""
                        }
                    }) {
                        Text("Go")
                    }
                },
            )
        } else {
            IconButton(
                onClick = { showSearch = true },
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp),
            ) {
                Text("\uD83D\uDD0D", style = MaterialTheme.typography.headlineSmall)
            }
        }

        // Map legend (bottom-left)
        MapLegend(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = 8.dp, bottom = 96.dp),
        )

        // Attribution text (bottom of map)
        Text(
            text = DisclaimerManager.ATTRIBUTION_TEXT,
            style = MaterialTheme.typography.labelSmall,
            color = Color.DarkGray,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 4.dp),
        )

        // DB error card
        if (dbError != null) {
            Card(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 64.dp, start = 16.dp, end = 16.dp)
                    .fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
            ) {
                Text(
                    text = dbError ?: "",
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        // Bottom: Park button or parking info sheet
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (parkedCar != null) {
                // Parking info card
                ParkingInfoCard(
                    streetName = parkedCar!!.streetName,
                    status = sweepingStatus,
                    onClearParking = { viewModel.clearParking() },
                    onSettingsClick = { showNotificationSettings = true },
                )
            } else {
                // "I Parked Here" button — uses GPS location
                Button(
                    onClick = {
                        // Request notification permission on API 33+
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(
                                    context,
                                    Manifest.permission.POST_NOTIFICATIONS,
                                ) != PackageManager.PERMISSION_GRANTED
                            ) {
                                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            }
                        }
                        // Use GPS location if available, fall back to camera center
                        if (hasLocationPermission.value) {
                            val fusedClient = LocationServices.getFusedLocationProviderClient(context)
                            try {
                                fusedClient.lastLocation.addOnSuccessListener { location ->
                                    if (location != null) {
                                        viewModel.parkCar(location.latitude, location.longitude)
                                    } else {
                                        val center = cameraPositionState.position.target
                                        viewModel.parkCar(center.latitude, center.longitude)
                                    }
                                }.addOnFailureListener {
                                    val center = cameraPositionState.position.target
                                    viewModel.parkCar(center.latitude, center.longitude)
                                }
                            } catch (_: SecurityException) {
                                val center = cameraPositionState.position.target
                                viewModel.parkCar(center.latitude, center.longitude)
                            }
                        } else {
                            val center = cameraPositionState.position.target
                            viewModel.parkCar(center.latitude, center.longitude)
                        }
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                    ),
                ) {
                    Text("I Parked Here")
                }
            }
        }
    }

    // Street info bottom sheet
    if (selectedSegment != null) {
        val segment = selectedSegment!!
        ModalBottomSheet(
            onDismissRequest = { viewModel.dismissStreetSheet() },
            sheetState = rememberModalBottomSheetState(),
        ) {
            StreetInfoSheet(
                segment = segment,
                onParkHere = {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(
                                context,
                                Manifest.permission.POST_NOTIFICATIONS,
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    }
                    val midCoord = segment.coordinates[segment.coordinates.size / 2]
                    viewModel.parkCar(midCoord.latitude, midCoord.longitude)
                    viewModel.dismissStreetSheet()
                },
            )
        }
    }
}

/**
 * Determines the map overlay color for a street segment based on day offset,
 * matching the iOS color system.
 */
private fun mapColorForSegment(segment: StreetSegment, today: LocalDate): Color {
    if (segment.rules.isEmpty()) return Color.Gray

    for (dayOffset in 0..3) {
        val date = today.plusDays(dayOffset.toLong())
        val isHoliday = HolidayCalculator.isHoliday(date)
        val anyRuleApplies = segment.rules.any { it.appliesTo(date, isHoliday) }
        if (anyRuleApplies) {
            return when (dayOffset) {
                0 -> Color.Red                  // Sweeping today
                1 -> Color(0xFFFF9800)          // Sweeping tomorrow (Orange)
                2, 3 -> Color(0xFFFFC107)       // Sweeping in 2-3 days (Yellow/Amber)
                else -> Color(0xFF4CAF50)       // Safe (Green)
            }
        }
    }

    return Color(0xFF4CAF50) // Safe — no sweeping within 3 days
}

/**
 * Search for an address and animate camera to it.
 */
private suspend fun searchAddress(
    context: android.content.Context,
    query: String,
    cameraPositionState: CameraPositionState,
) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        val geocoder = Geocoder(context, Locale.getDefault())
        geocoder.getFromLocationName(query, 1) { results ->
            results.firstOrNull()?.let { address ->
                // Note: This callback may not be on main thread, but CameraPositionState
                // handles thread safety internally
                kotlinx.coroutines.runBlocking {
                    cameraPositionState.animate(
                        CameraUpdateFactory.newLatLngZoom(
                            LatLng(address.latitude, address.longitude),
                            17f,
                        )
                    )
                }
            }
        }
    } else {
        @Suppress("DEPRECATION")
        val geocoder = Geocoder(context, Locale.getDefault())
        @Suppress("DEPRECATION")
        val results = geocoder.getFromLocationName(query, 1)
        results?.firstOrNull()?.let { address ->
            cameraPositionState.animate(
                CameraUpdateFactory.newLatLngZoom(
                    LatLng(address.latitude, address.longitude),
                    17f,
                )
            )
        }
    }
}

@Composable
fun MapLegend(modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
    ) {
        Column(modifier = Modifier.padding(8.dp)) {
            LegendItem(color = Color.Red, label = "Today")
            LegendItem(color = Color(0xFFFF9800), label = "Tomorrow")
            LegendItem(color = Color(0xFFFFC107), label = "2-3 Days")
            LegendItem(color = Color(0xFF4CAF50), label = "Safe")
            LegendItem(color = Color.Gray, label = "No Data")
        }
    }
}

@Composable
private fun LegendItem(color: Color, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(vertical = 2.dp),
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .background(color, shape = CircleShape),
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(text = label, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
fun ParkingInfoCard(
    streetName: String,
    status: SweepingStatus,
    onClearParking: () -> Unit,
    onSettingsClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = streetName,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onSettingsClick) {
                    Icon(
                        Icons.Default.Settings,
                        contentDescription = "Notification settings",
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            val (statusText, statusColor) = when (status) {
                is SweepingStatus.Safe -> "Safe to park" to Color(0xFF4CAF50)
                is SweepingStatus.Today -> {
                    val timeStr = status.time.format(DateTimeFormatter.ofPattern("h:mm a"))
                    "Sweeping today at $timeStr" to Color(0xFFFF9800)
                }
                is SweepingStatus.ActiveNow -> {
                    "Sweeping in progress! Move your car!" to Color.Red
                }
                is SweepingStatus.Imminent -> {
                    val timeStr = status.time.format(DateTimeFormatter.ofPattern("h:mm a"))
                    "Sweeping imminent at $timeStr!" to Color.Red
                }
                is SweepingStatus.Upcoming -> {
                    val timeStr = status.time.format(DateTimeFormatter.ofPattern("EEE, MMM d 'at' h:mm a"))
                    "Next sweeping: $timeStr" to Color(0xFF4CAF50)
                }
                is SweepingStatus.NoData -> "No sweeping data available" to Color.Gray
                is SweepingStatus.Unknown -> "Status unknown" to Color.Gray
            }

            Text(
                text = statusText,
                color = statusColor,
                style = MaterialTheme.typography.bodyLarge,
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedButton(
                onClick = onClearParking,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Clear Parking")
            }
        }
    }
}

@Composable
fun StreetInfoSheet(
    segment: StreetSegment,
    onParkHere: () -> Unit,
) {
    val now = LocalDateTime.now()
    val status = SweepingRuleEngine.getStatus(segment.rules, segment.streetName, now)
    val nextTime = SweepingRuleEngine.getNextSweepingTime(segment.rules, now)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 32.dp),
    ) {
        Text(
            text = segment.streetName,
            style = MaterialTheme.typography.headlineSmall,
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Next sweeping — color-coded
        if (nextTime != null) {
            val hoursUntil = Duration.between(now, nextTime).toHours()
            val (label, labelColor) = when {
                status is SweepingStatus.ActiveNow -> {
                    "Sweeping in progress! Move your car!" to Color.Red
                }
                status is SweepingStatus.Imminent || status is SweepingStatus.Today -> {
                    val t = nextTime.format(DateTimeFormatter.ofPattern("h:mm a"))
                    "Sweeping today at $t" to Color.Red
                }
                hoursUntil <= 48 -> {
                    val t = nextTime.format(DateTimeFormatter.ofPattern("EEE, MMM d 'at' h:mm a"))
                    "Next sweeping: $t" to Color(0xFFFF9800)
                }
                else -> {
                    val t = nextTime.format(DateTimeFormatter.ofPattern("EEE, MMM d 'at' h:mm a"))
                    "Next sweeping: $t" to Color(0xFF4CAF50)
                }
            }
            Text(text = label, color = labelColor, style = MaterialTheme.typography.bodyLarge)
        } else {
            Text(
                text = "No upcoming sweeping scheduled",
                color = Color.Gray,
                style = MaterialTheme.typography.bodyLarge,
            )
        }

        Spacer(modifier = Modifier.height(16.dp))
        HorizontalDivider()
        Spacer(modifier = Modifier.height(12.dp))

        Text("Weekly Schedule", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))

        if (segment.rules.isEmpty()) {
            Text("No sweeping rules on file", color = Color.Gray)
        } else {
            segment.rules.sortedBy { it.dayOfWeek }.forEach { rule ->
                val day = rule.dayOfWeek.getDisplayName(
                    java.time.format.TextStyle.FULL,
                    Locale.getDefault(),
                )
                val start = rule.startTime.format(DateTimeFormatter.ofPattern("h:mm a"))
                val end = rule.endTime.format(DateTimeFormatter.ofPattern("h:mm a"))
                val week = when (rule.weekOfMonth) {
                    0 -> "every week"
                    1 -> "1st week"
                    2 -> "2nd week"
                    3 -> "3rd week"
                    4 -> "4th week"
                    else -> "week ${rule.weekOfMonth}"
                }
                Text(
                    text = "$day  $start \u2013 $end  ($week)",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(vertical = 2.dp),
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        Button(
            onClick = onParkHere,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
        ) {
            Text("Park Here")
        }
    }
}

@Composable
fun NotificationSettingsDialog(
    currentLeadMinutes: Int,
    onDismiss: () -> Unit,
    onSelected: (Int) -> Unit,
) {
    val options = listOf(15, 30, 60, 120)
    val labels = listOf("15 minutes", "30 minutes", "1 hour", "2 hours")
    var selected by remember { mutableIntStateOf(currentLeadMinutes) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Notification Timing") },
        text = {
            Column {
                Text(
                    "How far in advance should we notify you?",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(modifier = Modifier.height(12.dp))
                options.forEachIndexed { index, minutes ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                    ) {
                        RadioButton(
                            selected = selected == minutes,
                            onClick = { selected = minutes },
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(labels[index])
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSelected(selected) }) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
    )
}
