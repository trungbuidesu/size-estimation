#include <opencv2/opencv.hpp>
#include <vector>
#include <string>
#include <iostream>
#include <limits>

// Cross-platform export macro
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

using namespace cv;
using namespace std;

extern "C" {

    /// Helper struct for Point Cloud limits
    struct Bounds {
        double minZ;
        double maxZ;
        bool valid;
    };

    // Helper: Undistort image (Simplified: assuming K is mostly linear or just strictly using K)
    // Actually standard SfM takes the raw image and uses K in findEssentialMat. 
    // We don't necessarily need to "undistort" pixels if we use the undistorted points for Essential Matrix.

    // 1. Feature Detection & Matching
    bool computeMatches(const Mat& img1, const Mat& img2, 
                       vector<KeyPoint>& kpts1, vector<KeyPoint>& kpts2, 
                       vector<DMatch>& good_matches) {
        
        Ptr<Feature2D> detector = SIFT::create(2000); // Or ORB::create(2000)
        Mat desc1, desc2;
        
        detector->detectAndCompute(img1, noArray(), kpts1, desc1);
        detector->detectAndCompute(img2, noArray(), kpts2, desc2);
        
        if (kpts1.size() < 100 || kpts2.size() < 100) return false;

        // Matching
        BFMatcher matcher(NORM_L2, true); // Cross check for SIFT
        vector<DMatch> matches;
        matcher.match(desc1, desc2, matches);

        // Sort and filter
        // Simple distance filter or keep top N
        std::sort(matches.begin(), matches.end(), [](const DMatch& a, const DMatch& b){
            return a.distance < b.distance;
        });

        // Keep top 80% or threshold? 
        // Let's use a simpler heuristic for stability
        int numGood = (int)(matches.size() * 0.15f);
        if (numGood < 50) numGood = matches.size();
        
        for(int i=0; i<numGood; ++i) {
            good_matches.push_back(matches[i]);
        }
        
        return good_matches.size() > 50;
    }

    // 2. Pairwise Structure from Motion
    Bounds processStereoPair(const Mat& img1, const Mat& img2, double focal, Point2d pp, double baseline) {
        vector<KeyPoint> kpts1, kpts2;
        vector<DMatch> matches;
        
        if (!computeMatches(img1, img2, kpts1, kpts2, matches)) {
            return {0, 0, false};
        }
        
        // Convert to Point2f
        vector<Point2f> pts1, pts2;
        for(const auto& m : matches) {
            pts1.push_back(kpts1[m.queryIdx].pt);
            pts2.push_back(kpts2[m.trainIdx].pt);
        }

        // Camera Matrix
        Mat K = Mat::eye(3, 3, CV_64F);
        K.at<double>(0,0) = focal;
        K.at<double>(1,1) = focal;
        K.at<double>(0,2) = pp.x;
        K.at<double>(1,2) = pp.y;

        // 3. Essential Matrix
        Mat mask;
        Mat E = findEssentialMat(pts1, pts2, K, RANSAC, 0.999, 1.0, mask);
        
        if (E.empty()) return {0, 0, false};

        // 4. Recover Pose (R, t)
        Mat R, t;
        int inliers = recoverPose(E, pts1, pts2, K, R, t, mask);
        
        if (inliers < 30) return {0, 0, false};

        // 5. Triangulation
        // We need 3x4 projection matrices
        // P1 = K [I | 0]
        // P2 = K [R | t] 
        // Note: 't' returned by recoverPose is unit vector (scale = 1).
        // We need to apply the known baseline. 
        // If 'baseline' is the magnitude of translation:
        
        t = t * baseline; // Scaling the translation vector directly

        Mat P1 = Mat::eye(3, 4, CV_64F);
        K.copyTo(P1.rowRange(0,3).colRange(0,3));
        
        Mat P2_Rt(3, 4, CV_64F);
        R.copyTo(P2_Rt.rowRange(0,3).colRange(0,3));
        t.copyTo(P2_Rt.rowRange(0,3).col(3));
        Mat P2 = K * P2_Rt;

        // Triangulate points
        // Filter points by mask from recoverPose
        vector<Point2f> tri_pts1, tri_pts2;
        for(int i=0; i<mask.rows; ++i) {
            if (mask.at<unsigned char>(i)) {
                tri_pts1.push_back(pts1[i]);
                tri_pts2.push_back(pts2[i]);
            }
        }

        Mat pts4D;
        triangulatePoints(P1, P2, tri_pts1, tri_pts2, pts4D);

        // Convert to 3D and find Height
        vector<Point3f> cloud;
        double minZ = std::numeric_limits<double>::max();
        double maxZ = std::numeric_limits<double>::lowest();

        // Accumulate valid points
        for(int i=0; i<pts4D.cols; ++i) {
            Mat col = pts4D.col(i);
            float w = col.at<float>(3);
            if (abs(w) < 1e-6) continue;
            
            float z = col.at<float>(2) / w;
            float y = col.at<float>(1) / w; // In computer vision, Y is usually down. Height might be Y or Z depending on orientation.
            // Let's assume standard object scanning where Y is vertical-ish relative to camera or we look for max spread.
            // Actually, "Height of object" usually implies Y-axis in camera coordinates if standing upright?
            // Or Z-axis if checking depth? 
            // PROMPT says: "Max Z and Min Z". I will stick to Z as requested.
            
            // Filter crazy outliers (behind camera or too far)
            if (z > 0 && z < baseline * 100) { // Reasonable depth limits
                if (z < minZ) minZ = z;
                if (z > maxZ) maxZ = z;
            }
        }
        
        if (minZ == std::numeric_limits<double>::max()) return {0,0,false};
        
        return {minZ, maxZ, true};
    }

    /// ENTRY POINT
    /// Returns height in cm, or negative error code
    EXPORT double EstimateHeightFromBaseline(char** imagePaths, int count, double knownBaselineCm, double fx, double cx, double cy) {
        if (count < 2) return -1.0;

        try {
            // Simplified Multi-View approach:
            // Calculate height from consecutive pairs (0-1, 1-2, etc) and average them to reduce noise.
            // Or just use the best pair.
            
            vector<string> paths;
            for(int i=0; i<count; ++i) {
                paths.push_back(string(imagePaths[i]));
            }

            double totalHeight = 0;
            int validPairs = 0;

            for(int i=0; i < count - 1; ++i) {
                Mat img1 = imread(paths[i], IMREAD_GRAYSCALE);
                Mat img2 = imread(paths[i+1], IMREAD_GRAYSCALE);
                
                if (img1.empty() || img2.empty()) continue;

                Bounds b = processStereoPair(img1, img2, fx, Point2d(cx, cy), knownBaselineCm);
                
                if (b.valid) {
                    // Logic: The "height" of an object in Z-depth terms usually means "thickness" or "depth extent".
                    // If the user effectively wants "Height" (Y-axis), the logic needs to change to MaxY - MinY.
                    // However, the prompt specifically asked: "Xác định điểm 3D cao nhất và thấp nhất... (max Z và min Z)".
                    // So I will return `maxZ - minZ` as requested. 
                    // Note: In typical camera view, Z is "forward". So this measures the depth of the object (thickness). 
                    // If the camera is looking DOWN at an object (top-down), Z is height.
                    
                    double h = b.maxZ - b.minZ;
                    
                    // Filter noise results
                    if (h > 0.1 && h < 500.0) { // arbitrary sanity checks
                        totalHeight += h;
                        validPairs++;
                    }
                }
            }

            if (validPairs == 0) return -2.0;

            return totalHeight / validPairs;

        } catch (...) {
            return -5.0; // Exception
        }
    }
}
