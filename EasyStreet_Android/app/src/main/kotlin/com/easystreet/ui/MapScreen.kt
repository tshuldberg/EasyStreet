package com.easystreet.ui

import android.Manifest
import android.content.pm.PackageManager
import android.location.Geocoder
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.easystreet.domain.engine.SweepingRuleEngine
import com.easystreet.domain.model.SweepingStatus
import com.google.android.gms.location.LocationServices
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

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

    var searchQuery by remember { mutableStateOf("") }
    var showSearch by remember { mutableStateOf(false) }

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

    // Notification permission launcher (Task 13 - API 33+)
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
            // Street overlays
            val now = LocalDateTime.now()
            visibleSegments.forEach { segment ->
                val status = SweepingRuleEngine.getStatus(segment.rules, segment.streetName, now)
                val color = when (status) {
                    is SweepingStatus.Imminent -> Color.Red
                    is SweepingStatus.Today -> Color.Red
                    is SweepingStatus.Upcoming -> Color.Green
                    is SweepingStatus.Safe -> Color.Green
                    is SweepingStatus.NoData -> Color.Gray
                    is SweepingStatus.Unknown -> Color.Gray
                }

                Polyline(
                    points = segment.coordinates.map { LatLng(it.latitude, it.longitude) },
                    color = color,
                    width = 8f,
                )
            }

            // Parked car marker with drag support (Task 12)
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

        // Search bar
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
                            @Suppress("DEPRECATION")
                            val geocoder = Geocoder(context, Locale.getDefault())
                            @Suppress("DEPRECATION")
                            val results = geocoder.getFromLocationName(searchQuery, 1)
                            results?.firstOrNull()?.let { address ->
                                cameraPositionState.animate(
                                    CameraUpdateFactory.newLatLngZoom(
                                        LatLng(address.latitude, address.longitude),
                                        17f,
                                    )
                                )
                            }
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
                )
            } else {
                // "I Parked Here" button
                Button(
                    onClick = {
                        // Request notification permission on API 33+ (Task 13)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(
                                    context,
                                    Manifest.permission.POST_NOTIFICATIONS,
                                ) != PackageManager.PERMISSION_GRANTED
                            ) {
                                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            }
                        }
                        val center = cameraPositionState.position.target
                        viewModel.parkCar(center.latitude, center.longitude)
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
}

@Composable
fun ParkingInfoCard(
    streetName: String,
    status: SweepingStatus,
    onClearParking: () -> Unit,
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
            Text(
                text = streetName,
                style = MaterialTheme.typography.titleMedium,
            )

            Spacer(modifier = Modifier.height(8.dp))

            val (statusText, statusColor) = when (status) {
                is SweepingStatus.Safe -> "Safe to park" to Color(0xFF4CAF50)
                is SweepingStatus.Today -> {
                    val timeStr = status.time.format(DateTimeFormatter.ofPattern("h:mm a"))
                    "Sweeping today at $timeStr" to Color(0xFFFF9800)
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
