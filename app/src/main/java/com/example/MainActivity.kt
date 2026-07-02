package com.example

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.core.animateFloatAsState
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.example.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                VizionAIApp()
            }
        }
    }
}

data class GenerationHistory(
    val id: String,
    val prompt: String,
    val ratio: String,
    val timestamp: Long
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VizionAIApp() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val sharedPrefs = remember { context.getSharedPreferences("vizionai_settings", android.content.Context.MODE_PRIVATE) }
    var replicateKey by remember { mutableStateOf(sharedPrefs.getString("replicate_key", "") ?: "") }
    
    val coroutineScope = rememberCoroutineScope()
    var prompt by remember { mutableStateOf("") }
    var ratio by remember { mutableStateOf("16:9") }
    var status by remember { mutableStateOf("idle") } // idle, loading, success
    var progress by remember { mutableFloatStateOf(0f) }
    var message by remember { mutableStateOf("") }
    var videoUrl by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    
    var showDirector by remember { mutableStateOf(false) }
    var showHistory by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    
    val historyList = remember { mutableStateListOf<GenerationHistory>() }

    val handleGenerate = {
        if (prompt.isNotBlank() && status != "loading") {
            if (replicateKey.isBlank()) {
                errorMessage = "Please configure your Replicate API Key in Settings."
                showSettings = true
            } else {
                status = "loading"
                progress = 0f
                videoUrl = null
                errorMessage = null
                coroutineScope.launch {
                    try {
                        val url = ReplicateApi.generateVideo(prompt, replicateKey) { msg, prog ->
                            message = msg
                            progress = prog
                        }
                        videoUrl = url
                        status = "success"
                        historyList.add(0, GenerationHistory(
                            id = UUID.randomUUID().toString(),
                            prompt = prompt,
                            ratio = ratio,
                            timestamp = System.currentTimeMillis()
                        ))
                    } catch (e: Exception) {
                        status = "idle"
                        errorMessage = "Generation Error: ${e.message}"
                    }
                }
            }
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = BgPrimary,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = BgPrimary,
                    titleContentColor = TextPrimary,
                    actionIconContentColor = TextSecondary
                ),
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("VizionAI", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        Spacer(modifier = Modifier.width(6.dp))
                        Box(
                            modifier = Modifier
                                .background(Color(0x1AFFFFFF), RoundedCornerShape(4.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Text(
                                "STUDIO",
                                color = AccentColor,
                                fontSize = 9.sp,
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 1.sp,
                                fontFamily = FontFamily.Monospace
                            )
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { showHistory = true }) {
                        Icon(Icons.Default.History, contentDescription = "History")
                    }
                    IconButton(onClick = { showDirector = true }) {
                        Icon(Icons.Default.Tune, contentDescription = "Director")
                    }
                    IconButton(onClick = { showSettings = true }) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                }
            )
        },
        bottomBar = {
            Column {
                PromptBar(
                    prompt = prompt,
                    onPromptChange = { prompt = it },
                    ratio = ratio,
                    onRatioChange = { ratio = it },
                    status = status,
                    onGenerate = handleGenerate,
                    onEnhance = {
                        coroutineScope.launch {
                            prompt += ", cinematic 4K ultra-realistic, dynamic lighting, high fidelity, 8k resolution textures, dramatic volume shadow"
                        }
                    }
                )
                StatusBar()
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(BgSecondary)
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (errorMessage != null) {
                    Text(
                        text = errorMessage!!,
                        color = MaterialTheme.colorScheme.error,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(bottom = 12.dp)
                    )
                }
                CanvasPreview(status, progress, message, videoUrl, ratio)
            }
        }
    }

    if (showDirector) {
        ModalBottomSheet(
            onDismissRequest = { showDirector = false },
            containerColor = BgSecondary,
            dragHandle = { BottomSheetDefaults.DragHandle(color = BorderColor) }
        ) {
            DirectorPanel(onClose = { showDirector = false })
        }
    }

    if (showHistory) {
        ModalBottomSheet(
            onDismissRequest = { showHistory = false },
            containerColor = BgSecondary,
            dragHandle = { BottomSheetDefaults.DragHandle(color = BorderColor) }
        ) {
            HistoryPanel(historyList = historyList)
        }
    }

    if (showSettings) {
        ModalBottomSheet(
            onDismissRequest = { showSettings = false },
            containerColor = BgSecondary,
            dragHandle = { BottomSheetDefaults.DragHandle(color = BorderColor) }
        ) {
            SettingsPanel(
                initialKey = replicateKey,
                onSave = { newKey ->
                    replicateKey = newKey
                    sharedPrefs.edit().putString("replicate_key", newKey).apply()
                    showSettings = false
                    errorMessage = null
                },
                onDismiss = { showSettings = false }
            )
        }
    }
}

@Composable
fun CanvasPreview(status: String, progress: Float, message: String, videoUrl: String?, ratio: String) {
    val aspectRatio = when (ratio) {
        "16:9" -> 16f / 9f
        "9:16" -> 9f / 16f
        "1:1" -> 1f
        "4:5" -> 4f / 5f
        "21:9" -> 21f / 9f
        else -> 16f / 9f
    }
    
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(aspectRatio)
            .clip(RoundedCornerShape(12.dp))
            .background(BgCard)
            .border(1.dp, BorderColor, RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center
    ) {
        when (status) {
            "idle" -> {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Outlined.Movie,
                        contentDescription = null,
                        tint = BorderColor,
                        modifier = Modifier.size(48.dp)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        "VizionAI Workspace Area",
                        color = Color.White.copy(alpha = 0.8f),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.5.sp
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "Parameters ready. Input prompt matrix instructions.",
                        color = TextSecondary,
                        fontSize = 11.sp
                    )
                }
            }
            "loading" -> {
                LoadingRing(progress = progress, message = message)
            }
            "success" -> {
                if (videoUrl != null) {
                    val context = androidx.compose.ui.platform.LocalContext.current
                    val exoPlayer = remember(videoUrl) {
                        ExoPlayer.Builder(context).build().apply {
                            setMediaItem(MediaItem.fromUri(Uri.parse(videoUrl)))
                            repeatMode = Player.REPEAT_MODE_ALL
                            prepare()
                            playWhenReady = true
                        }
                    }
                    
                    DisposableEffect(exoPlayer) {
                        onDispose {
                            exoPlayer.release()
                        }
                    }

                    AndroidView(
                        factory = { ctx ->
                            PlayerView(ctx).apply {
                                player = exoPlayer
                                useController = true
                                resizeMode = androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT
                                layoutParams = android.view.ViewGroup.LayoutParams(
                                    android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                                    android.view.ViewGroup.LayoutParams.MATCH_PARENT
                                )
                            }
                        },
                        update = { playerView ->
                            playerView.player = exoPlayer
                        },
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
    }
}

@Composable
fun LoadingRing(progress: Float, message: String) {
    val animatedProgress by animateFloatAsState(targetValue = progress, label = "progress")
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(64.dp)) {
            CircularProgressIndicator(
                progress = { 1f },
                modifier = Modifier.fillMaxSize(),
                color = Color(0x1AFFFFFF),
                strokeWidth = 4.dp
            )
            CircularProgressIndicator(
                progress = { animatedProgress },
                modifier = Modifier.fillMaxSize(),
                color = AccentColor,
                strokeWidth = 4.dp
            )
            Text(
                "${(animatedProgress * 100).toInt()}%",
                color = AccentColor,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace
            )
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            message,
            color = TextSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 1.sp
        )
    }
}

@Composable
fun PromptBar(
    prompt: String,
    onPromptChange: (String) -> Unit,
    ratio: String,
    onRatioChange: (String) -> Unit,
    status: String,
    onGenerate: () -> Unit,
    onEnhance: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            .background(BgPrimary)
            .border(1.dp, BorderColor, RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            .padding(16.dp)
            .navigationBarsPadding()
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedButton(
                onClick = { /* TODO */ },
                colors = ButtonDefaults.outlinedButtonColors(contentColor = TextSecondary),
                border = BorderStroke(1.dp, BorderColor),
                shape = RoundedCornerShape(6.dp),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
                modifier = Modifier.height(28.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add", modifier = Modifier.size(14.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("REFERENCE CONTEXT", fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            }

            Row(
                modifier = Modifier
                    .border(1.dp, BorderColor, RoundedCornerShape(6.dp))
                    .background(Color(0x0AFFFFFF))
                    .padding(2.dp)
            ) {
                val ratios = listOf("9:16", "16:9", "1:1", "4:5", "21:9")
                ratios.forEach { r ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(if (ratio == r) AccentColor else Color.Transparent)
                            .clickable { onRatioChange(r) }
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            r,
                            color = if (ratio == r) Color.Black else TextSecondary,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace
                        )
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(12.dp))
        
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, BorderColor, RoundedCornerShape(8.dp))
                .background(Color(0xFF0D0D0D), RoundedCornerShape(8.dp))
                .padding(12.dp)
        ) {
            BasicTextField(
                value = prompt,
                onValueChange = onPromptChange,
                textStyle = TextStyle(color = Color.White, fontSize = 14.sp),
                cursorBrush = SolidColor(AccentColor),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
            )
            if (prompt.isEmpty()) {
                Text(
                    "Describe the scene of your dreams... (e.g., An astronaut walking on a golden planet, cinematic 4K)",
                    color = Color(0xFF666666),
                    fontSize = 14.sp
                )
            }
        }
        
        Spacer(modifier = Modifier.height(12.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(
                onClick = onEnhance,
                enabled = prompt.isNotBlank(),
                colors = ButtonDefaults.textButtonColors(
                    contentColor = TextSecondary,
                    disabledContentColor = Color.White.copy(alpha = 0.2f)
                )
            ) {
                Icon(Icons.Default.AutoAwesome, contentDescription = "Enhance", modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("✦ ENHANCE", fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            }
            
            Button(
                onClick = onGenerate,
                enabled = prompt.isNotBlank() && status != "loading",
                colors = ButtonDefaults.buttonColors(
                    containerColor = AccentColor,
                    contentColor = Color.Black,
                    disabledContainerColor = AccentColor.copy(alpha = 0.4f),
                    disabledContentColor = Color.Black.copy(alpha = 0.4f)
                ),
                shape = RoundedCornerShape(6.dp),
                contentPadding = PaddingValues(horizontal = 24.dp, vertical = 0.dp),
                modifier = Modifier.height(36.dp)
            ) {
                Text("GENERATE SCENE (4K)", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            }
        }
    }
}

@Composable
fun StatusBar() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(BgSecondary)
            .border(BorderStroke(1.dp, BorderColor))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier
                .size(6.dp)
                .background(Color(0xFF10B981), CircleShape))
            Spacer(modifier = Modifier.width(6.dp))
            Text("SIMULATOR ENGAGED", color = TextSecondary, fontSize = 10.sp, fontFamily = FontFamily.Monospace)
        }
        Text("V2.0.0 — CONTROL+ENTER", color = TextSecondary, fontSize = 10.sp, fontFamily = FontFamily.Monospace)
    }
}

@Composable
fun DirectorPanel(onClose: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp)
            .navigationBarsPadding()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("DIRECTOR PANEL", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            Text("RESET", color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, modifier = Modifier.clickable { })
        }
        Divider(color = BorderColor)
        Spacer(modifier = Modifier.height(16.dp))
        
        Text("AI ENGINE VECTOR", color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, BorderColor, RoundedCornerShape(4.dp))
                .background(Color(0xFF0D0D0D))
                .padding(12.dp)
        ) {
            Text("Stability Video Diffusion (SVD)", color = Color.White, fontSize = 12.sp)
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        Divider(color = BorderColor)
        Spacer(modifier = Modifier.height(16.dp))
        
        Text("CAMERA POSITIONING MATRIX", color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(modifier = Modifier.height(16.dp))
        SliderControl("Pan", 0f)
        SliderControl("Tilt", 0f)
        SliderControl("Zoom", 0f)
        
        Spacer(modifier = Modifier.height(24.dp))
        Divider(color = BorderColor)
        Spacer(modifier = Modifier.height(16.dp))
        
        Text("KINEMATICS & SPATIAL FLUIDITY", color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(modifier = Modifier.height(16.dp))
        SliderControl("Fluidity Dynamics", 50f)
        SliderControl("Gravity Coefficient", 50f)
    }
}

@Composable
fun SliderControl(label: String, value: Float) {
    var currentValue by remember { mutableFloatStateOf(value) }
    Column(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, color = TextSecondary, fontSize = 12.sp)
            Text(currentValue.toInt().toString(), color = AccentColor, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
        }
        Slider(
            value = currentValue,
            onValueChange = { currentValue = it },
            valueRange = -100f..100f,
            colors = SliderDefaults.colors(
                thumbColor = AccentColor,
                activeTrackColor = AccentColor,
                inactiveTrackColor = Color(0x1AFFFFFF)
            )
        )
    }
}

@Composable
fun HistoryPanel(historyList: List<GenerationHistory>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp)
            .navigationBarsPadding()
    ) {
        Text("GENERATION INDEX", color = AccentColor, fontSize = 14.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(modifier = Modifier.height(16.dp))
        Divider(color = BorderColor)
        Spacer(modifier = Modifier.height(16.dp))
        
        if (historyList.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp), contentAlignment = Alignment.Center) {
                Text("EMPTY INDEX LOG", color = TextSecondary, fontSize = 10.sp, fontFamily = FontFamily.Monospace, letterSpacing = 1.sp)
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
                items(historyList) { item ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp)
                            .border(1.dp, BorderColor, RoundedCornerShape(6.dp))
                            .background(BgCard)
                            .clickable { }
                            .padding(12.dp)
                    ) {
                        Column {
                            Text(
                                item.prompt,
                                color = Color.White.copy(alpha = 0.9f),
                                fontSize = 12.sp,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(item.ratio, color = TextSecondary, fontSize = 9.sp, fontFamily = FontFamily.Monospace)
                                val dateStr = SimpleDateFormat("MM/dd/yyyy", Locale.US).format(Date(item.timestamp))
                                Text(dateStr, color = TextSecondary, fontSize = 9.sp, fontFamily = FontFamily.Monospace)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SettingsPanel(initialKey: String, onSave: (String) -> Unit, onDismiss: () -> Unit) {
    var key by remember { mutableStateOf(initialKey) }
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp)
            .navigationBarsPadding()
    ) {
        Text("SECURITY CREDENTIALS DASHBOARD", color = AccentColor, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(modifier = Modifier.height(16.dp))
        Divider(color = BorderColor)
        Spacer(modifier = Modifier.height(16.dp))
        
        SettingsInput("REPLICATE ENGINE API KEY", "r8_••••••••••••••••••••••••", key) { key = it }
        
        Spacer(modifier = Modifier.height(16.dp))
        Divider(color = BorderColor)
        Spacer(modifier = Modifier.height(16.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End
        ) {
            OutlinedButton(
                onClick = onDismiss,
                colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.White),
                border = BorderStroke(1.dp, BorderColor),
                shape = RoundedCornerShape(6.dp)
            ) {
                Text("DISMISS", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(modifier = Modifier.width(8.dp))
            Button(
                onClick = { onSave(key) },
                colors = ButtonDefaults.buttonColors(containerColor = AccentColor, contentColor = Color.Black),
                shape = RoundedCornerShape(6.dp)
            ) {
                Text("SAVE TOKEN MATRIX", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun SettingsInput(label: String, placeholder: String, value: String, onValueChange: (String) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
        Text(label, color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(modifier = Modifier.height(8.dp))
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = TextStyle(color = Color.White, fontSize = 12.sp, fontFamily = FontFamily.Monospace),
            cursorBrush = SolidColor(AccentColor),
            decorationBox = { innerTextField ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, BorderColor, RoundedCornerShape(4.dp))
                        .background(Color(0xFF0D0D0D))
                        .padding(horizontal = 12.dp, vertical = 10.dp)
                ) {
                    if (value.isEmpty()) {
                        Text(placeholder, color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                    }
                    innerTextField()
                }
            }
        )
    }
}
