class AppStrings {
  // Methods Screen
  static const String appTitle = 'Đo Khoảng Cách & Kích Thước';
  static const String methodsTitle = 'Chọn phương pháp đo';

  // Methods Screen
  static const String mainFunctions = 'Chức năng chính';
  static const String settingsTooltip = 'Cài đặt';
  static const String cameraPropsTooltip = 'Thuộc tính Camera';
  static const String measureObjectSize = 'Đo kích thước vật thể';
  static const String estimateObjectSize = 'Ước lượng kích thước vật thể';
  static const String estimateObjectSubtitle =
      'Sử dụng các module khác nhau để đo đạc.';
  static const String useAdvancedCorrection = 'Sử dụng hiệu chỉnh ảnh nâng cao';
  static const String advancedTools = 'Công cụ nâng cao';
  static const String advancedCalibration = 'Hiệu chỉnh ảnh nâng cao';
  static const String calibrationPlayground = 'Calibration Playground';
  static const String notAvailable = 'Không khả dụng trên thiết bị này';

  static const String defaultProfileName = "Mặc định (Device Intrinsics)";
  static const String checkParams = "Kiểm tra thông số";
  static const String errorPrefix = "Lỗi: ";
  static const String statusCannotRead = "Không thể đọc thông số từ Camera API";
  static const String intrinsicsHeader = "Intrinsics (Pinhole Model)";
  static const String distortionHeader = "Distortion (Radial)";
  static const String startPrompt =
      "Nhấn 'Bắt đầu' để sử dụng các thông số này.";
  static const String back = "Quay lại";
  static const String start = "Bắt đầu";

  static const String multiImageTitle = 'Nhiều ảnh từ các góc độ';
  static const String multiImageDesc =
      '- Chụp/tải nhiều ảnh ở các góc khác nhau.\n'
      '- Hệ thống xử lý ảnh để ước lượng kích thước/khối tích.\n'
      '- Hoạt động trên hầu hết thiết bị, không cần AR.';
  static const String quickTips = 'Mẹo nhanh:';
  static const String quickTipsDesc =
      '- Chụp 4-6 góc (trước/sau/trái/phải/chéo trên/dưới).\n'
      '- Đủ sáng, tránh bóng gắt.\n'
      '- Có vật chuẩn kích thước (thẻ, tờ A4) càng tốt.';
  static const String viewDetailedGuide = 'Xem hướng dẫn chi tiết';
  static const String tutorialTodo =
      'Mở tutorial (TODO: liên kết tới màn hướng dẫn)';

  static const String noCalibrationData = 'Không có dữ liệu hiệu chỉnh';
  static const String noCalibrationContent =
      'Bạn chưa tạo profile hiệu chỉnh nào.\nHệ thống sẽ sử dụng thông số mặc định từ Camera.';
  static const String understood = 'Đã hiểu';

  // Calibration Playground
  static const String calibrationTitle = 'Hiệu Chuẩn (Calibration)';
  static const String errorPickImage = 'Lỗi khi chọn ảnh: ';
  static const String errorCaptureImage = 'Lỗi khi chụp ảnh: ';
  static const String minImagesRequired =
      'Cần ít nhất 10 hình ảnh để hiệu chuẩn. Hiện tại: ';
  static const String calibrationFailed = 'Hiệu chuẩn thất bại';
  static const String calibrationFailedPrefix = 'Hiệu chuẩn thất bại: ';
  static const String saveProfileTitle = 'Lưu Hồ Sơ Hiệu Chuẩn';
  static const String profileNameLabel = 'Tên Hồ Sơ';
  static const String profileNameHint = 'Ví dụ: Hiệu chuẩn của tôi';
  static const String cancel = 'Hủy';
  static const String save = 'Lưu';
  static const String saveProfileSuccess = 'Đã lưu hồ sơ "'; // + name + '"!'
  static const String saveTooltip = 'Lưu Hồ Sơ';

  static const String calibrationGuideTitle = 'Hướng Dẫn Hiệu Chuẩn';
  static const String step1 = 'In mẫu ChArUco (ví dụ: 5x7 hoặc 8x11)';
  static const String step2 =
      'Chụp 15-30 ảnh từ các góc độ và khoảng cách khác nhau';
  static const String step3 = 'Đảm bảo toàn bộ bảng đều nằm trong khung hình';
  static const String step4 = 'Nhấn "Chạy Hiệu Chuẩn" để xử lý';

  static const String targetSettingsTitle = 'Cài Đặt Mục Tiêu';
  static const String boardWidthLabel = 'Chiều Rộng Bảng [mm]';
  static const String boardHeightLabel = 'Chiều Cao Bảng [mm]';
  static const String rowsLabel = 'Số Hàng';
  static const String columnsLabel = 'Số Cột';
  static const String squareSizeLabel = 'Kích Thước Ô Vuông (mm)';
  static const String dictLabel = 'Từ Điển Marker';
  static const String startIdLabel = 'ID Bắt Đầu';

  static const String captureTooltip = 'Chụp ảnh';
  static const String libraryTooltip = 'Chọn từ thư viện';
  static const String imagesHeader = 'Hình Ảnh ('; // + length + ')'
  static const String noImages = 'Chưa có hình ảnh nào';

  static const String processing = 'Đang xử lý...';
  static const String runCalibration = 'Chạy Hiệu Chuẩn';

  static const String calibrationComplete = 'Hiệu Chuẩn Hoàn Tất';
  static const String rmsError = 'Sai số RMS';

  static const String charucoInfoTitle = 'ChArUco Board là gì?';
  static const String charucoInfoDesc =
      'Bảng ChArUco là sự kết hợp giữa bàn cờ vua tiêu chuẩn và các điểm đánh dấu ArUco. '
      'Các ô trắng của bàn cờ chứa các marker ArUco nhỏ. '
      'Thiết kế lai này mang lại độ chính xác cao của việc phát hiện góc bàn cờ '
      'cùng với sự mạnh mẽ của việc nhận dạng marker, cho phép hiệu chuẩn ngay cả khi bảng bị che khuất một phần.';
  static const String simpleIllustration = 'Minh họa đơn giản';
  static const String paramExplanation = 'Giải thích thông số:';

  static const String paramBoard = 'Bảng';
  static const String paramBoardDesc =
      'Chiều rộng/cao vật lý của toàn bộ bảng giấy';
  static const String paramRowCol = 'Hàng/Cột';
  static const String paramRowColDesc = 'Số lượng ô vuông theo chiều dọc/ngang';
  static const String paramSquare = 'Ô Vuông';
  static const String paramSquareDesc =
      'Kích thước cạnh của một ô vuông đen/trắng';
  static const String paramDict = 'Từ Điển';
  static const String paramDictDesc =
      'Bộ từ điển ArUco được sử dụng để tạo marker';
  static const String paramStartId = 'ID Bắt Đầu';
  static const String paramStartIdDesc = 'ID của marker đầu tiên (thường là 0)';

  // Camera Properties
  static const String cameraPropsTitle = 'Thông số camera';
  static const String propLensIntrinsic = 'Lens Intrinsic Calibration';
  static const String propLensIntrinsicDesc = 'Hiệu chuẩn nội tại ống kính';
  static const String propLensDistortion = 'Lens Radial Distortion';
  static const String propLensDistortionDesc = 'Biến dạng hướng tâm ống kính';
  static const String propSensorPhysical = 'Sensor Info Physical Size';
  static const String propSensorPhysicalDesc = 'Kích thước vật lý cảm biến';
  static const String propSensorActive = 'Sensor Info Active Array Size';
  static const String propSensorActiveDesc = 'Kích thước mảng hoạt động';
  static const String propCapabilities = 'Request Available Capabilities';
  static const String propCapabilitiesDesc = 'Các khả năng hiện có';
  static const String propCropRegion = 'Scaler Crop Region';
  static const String propCropRegionDesc = 'Vùng cắt tỷ lệ (Zoom)';

  static const String close = 'Đóng';
  static const String description = 'Mô tả';
  static const String purpose = 'Mục đích';
  static const String ifMissing = 'Nếu thiếu';
  static const String na = 'N/A';
  static const String unknown = 'Không xác định.';
  static const String noDesc = 'Không có mô tả.';

  static const String scoreTitle = 'ĐIỂM HIỆU NĂNG (BETA)';
  static const String scoreExcellent = 'Tuyệt vời cho Photogrammetry';
  static const String scoreGood = 'Đủ điều kiện cơ bản';
  static const String scoreLimited = 'Hạn chế tính năng';

  static const String scoreSpatial = 'Không gian & Cảm biến';
  static const String scoreProcessing = 'Xử lý hình ảnh';
  static const String scoreCompat = 'Tương thích';
  static const String scoreSupportDepth = 'Hỗ trợ Depth';
  static const String scoreSupportIntrinsics = 'Hỗ trợ Intrinsics';

  static const String failedGetProps = "Failed to get camera properties: '";
  static const String errorOccurred = "An error occurred: ";

  // Detailed info
  static const String infoIntrinsicDesc =
      'Các tham số mô tả sự ánh xạ từ không gian 3D sang mặt phẳng hình ảnh 2D (tiêu cự, điểm chính).';
  static const String infoIntrinsicPurpose =
      'Cần thiết để chuyển đổi các điểm ảnh 2D trở lại thành các tia 3D. Được sử dụng trong đo lường chính xác.';
  static const String infoIntrinsicMissing =
      'Không thể tái tạo chính xác hình học 3D từ một hình ảnh duy nhất. Các tính toán kích thước sẽ không chính xác.';

  static const String infoDistortionDesc =
      'Các hệ số mô tả cách ống kính bẻ cong ánh sáng (biến dạng thùng/gối).';
  static const String infoDistortionPurpose =
      'Sửa biến dạng hình học để các đường thẳng trong thực tế cũng thẳng trong hình ảnh.';
  static const String infoDistortionMissing =
      'Các phép đo gần các cạnh của hình ảnh sẽ không chính xác.';

  static const String infoSensorPhysDesc =
      'Kích thước vật lý (chiều rộng x chiều cao) của cảm biến camera tính bằng milimet.';
  static const String infoSensorPhysPurpose =
      'Xác định tỷ lệ vật lý của các đối tượng được chiếu lên cảm biến. Quan trọng để tính toán "pixel trên milimet".';
  static const String infoSensorPhysMissing =
      'Không thể tính toán kích thước thế giới thực từ pixel nếu không có đối tượng tham chiếu đã biết.';

  static const String infoSensorActiveDesc =
      'Vùng của cảm biến thực sự được sử dụng để chụp ảnh (tính bằng pixel).';
  static const String infoSensorActivePurpose =
      'Được sử dụng cùng với kích thước vật lý để tính kích thước điểm ảnh (kích thước vật lý của một pixel).';
  static const String infoSensorActiveMissing =
      'Không thể ánh xạ tọa độ pixel sang tọa độ cảm biến vật lý một cách chính xác.';

  static const String infoCapsDesc =
      'Danh sách các tính năng mà camera hỗ trợ (ví dụ: RAW, MANUAL_SENSOR, DEPTH_OUTPUT).';
  static const String infoCapsPurpose =
      'Kiểm tra xem thiết bị có hỗ trợ các tính năng nâng cao như ước lượng độ sâu hoặc điều khiển thủ công hay không.';
  static const String infoCapsMissing =
      'Ứng dụng có thể giả định các khả năng không có, dẫn đến sự cố hoặc tính năng bị thiếu.';

  static const String infoCropDesc =
      'Vùng của cảm biến hiện đang được đọc để tạo ra luồng hình ảnh.';
  static const String infoCropPurpose =
      'Triển khai zoom kỹ thuật số. Cho biết phần nào của cảm biến đầy đủ tương ứng với khung hình hiện tại của bạn.';
  static const String infoCropMissing =
      'Mức zoom kỹ thuật số không xác định. Các phép đo sẽ hoàn toàn sai nếu người dùng phóng to.';
  // Camera Screen
  static const String modeGroundPlane = 'Ground Plane';
  static const String modeGroundPlaneDesc =
      'Đo khoảng cách trên mặt phẳng ngang';
  static const String modePlanarObject = 'Planar Object';
  static const String modePlanarObjectDesc =
      'Đo kích thước vật phẳng với tham chiếu';
  static const String modeVerticalObject = 'Vertical Object';
  static const String modeVerticalObjectDesc = 'Đo chiều cao vật thẳng đứng';
  static const String modeMultiFrame = 'Multi-frame';
  static const String modeMultiFrameDesc =
      'Đo từ nhiều frame để tăng độ chính xác';

  static const String cameraNotFound = 'Không tìm thấy camera';
  static const String initCameraError = 'Lỗi khởi tạo camera: ';

  static const String maxImagesReached =
      'Đã đủ số lượng ảnh. Vui lòng xóa bớt hoặc nhấn Hoàn tất.';
  static const String selectModeRequired =
      'Vui lòng chọn chế độ đo trước khi chụp ảnh.';
  static const String selectPointsGround = 'Vui lòng chọn 2 điểm trên mặt đất.';
  static const String selectPointsPlanar = 'Vui lòng chọn 4 góc của vật thể.';
  static const String selectPointsVertical =
      'Vui lòng chọn điểm đầu và chân vật thể.';

  static const String deviceUnstable =
      'Thiết bị đang rung. Vui lòng giữ chắc tay.';
  static const String deviceTilted =
      'Thiết bị bị nghiêng. Vui lòng giữ cân bằng.';
  static const String zoomWarning =
      'Cảnh báo: Mức zoom hiện tại quá cao. Ảnh có thể bị mờ, giảm độ chính xác SfM.';
  static const String captureError = 'Lỗi chụp ảnh: ';

  static const String qualityWarningTitle = 'Chất lượng ảnh kém';
  static const String resultTitle = 'Kết quả';
  static const String estimatedHeight = 'Chiều cao ước lượng';
  static const String refresh = 'Làm mới';
  static const String errorTitle = 'Lỗi';

  static const String galleryTitle = 'Ảnh đã chụp';

  static const String multiFrameAveragingTitle = 'Trung bình đa khung hình';

  static const String multiFrameAveragingProcess = '''
Sử dụng video của nhiều khung hình để giảm nhiễu.

Quy trình:
1. Người dùng quay một video ngắn hoặc chụp nhiều khung hình.
2. Theo dõi các điểm A, B qua các khung hình (sử dụng Lucas–Kanade hoặc khớp đặc trưng).
3. Tính toán phép đo cho từng khung hình.
4. Hợp nhất các kết quả (trung vị/trung bình) để loại bỏ các ngoại lệ.
''';

  static const String multiFrameAveragingBenefit = '''
Lợi ích:
Giảm tác động của nhiễu IMU, lỗi khi nhấp chuột và rung máy ảnh.
''';
}
