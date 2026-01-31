import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdCard extends StatefulWidget {
  final double iconSize;
  const AdCard({super.key, required this.iconSize});

  @override
  State<AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  // Replace with your real Native Ad ID
  final String _adUnitId = 'ca-app-pub-3940256099942544/2247696110';

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('$NativeAd loaded.');
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('$NativeAd failed to load: $error');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
      // Custom native template can be used or we can use the default platform ones
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: const Color(0xFF1A1A2E),
        cornerRadius: 4.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF00D4FF),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white70,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_nativeAdIsLoaded) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.rocket_launch,
                color: Color(0xFF00D4FF),
                size: 32,
              ),
            ),
            // Bottom left icon placeholder
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                width: widget.iconSize,
                height: widget.iconSize,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'AD',
                    style: TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF00D4FF).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            AdWidget(ad: _nativeAd!),
            // Ad Badge (Top Right)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'SPONSORED',
                  style: TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // App Style Icon (Bottom Left)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                width: widget.iconSize,
                height: widget.iconSize,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: const Center(
                  child: Text(
                    'AD',
                    style: TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
