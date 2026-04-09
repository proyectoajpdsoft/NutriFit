package com.aprendeconpatricia.nutrifit

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class NativeAdvancedAdFactory(
	private val layoutInflater: LayoutInflater,
) : NativeAdFactory {
	override fun createNativeAd(
		nativeAd: NativeAd,
		customOptions: MutableMap<String, Any>?,
	): NativeAdView {
		val template = customOptions?.get("template") as? String ?: "small_card"
		val layoutRes = when (template) {
			"compact" -> R.layout.native_ad_compact
			"large_card" -> R.layout.native_ad_large_card
			else -> R.layout.native_ad_small_card
		}

		val adView = layoutInflater.inflate(layoutRes, null) as NativeAdView

		adView.mediaView = adView.findViewById(R.id.ad_media)
		adView.headlineView = adView.findViewById(R.id.ad_headline)
		adView.bodyView = adView.findViewById(R.id.ad_body)
		adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
		adView.iconView = adView.findViewById(R.id.ad_app_icon)
		adView.priceView = adView.findViewById(R.id.ad_price)
		adView.storeView = adView.findViewById(R.id.ad_store)
		adView.starRatingView = adView.findViewById(R.id.ad_stars)
		adView.advertiserView = adView.findViewById(R.id.ad_advertiser)

		(adView.headlineView as TextView).text = nativeAd.headline

		val mediaView = adView.mediaView
		if (nativeAd.mediaContent != null && mediaView != null) {
			mediaView.mediaContent = nativeAd.mediaContent
			mediaView.visibility = View.VISIBLE
		} else {
			mediaView?.visibility = View.GONE
		}

		val bodyView = adView.bodyView as TextView
		if (nativeAd.body.isNullOrBlank()) {
			bodyView.visibility = View.GONE
		} else {
			bodyView.text = nativeAd.body
			bodyView.visibility = View.VISIBLE
		}

		val ctaView = adView.callToActionView as Button
		if (nativeAd.callToAction.isNullOrBlank()) {
			ctaView.visibility = View.GONE
		} else {
			ctaView.text = nativeAd.callToAction
			ctaView.visibility = View.VISIBLE
		}

		val iconView = adView.iconView as ImageView
		if (nativeAd.icon == null) {
			iconView.visibility = View.GONE
		} else {
			iconView.setImageDrawable(nativeAd.icon?.drawable)
			iconView.visibility = View.VISIBLE
		}

		val priceView = adView.priceView as TextView
		if (nativeAd.price.isNullOrBlank()) {
			priceView.visibility = View.GONE
		} else {
			priceView.text = nativeAd.price
			priceView.visibility = View.VISIBLE
		}

		val storeView = adView.storeView as TextView
		if (nativeAd.store.isNullOrBlank()) {
			storeView.visibility = View.GONE
		} else {
			storeView.text = nativeAd.store
			storeView.visibility = View.VISIBLE
		}

		val starRatingView = adView.starRatingView as RatingBar
		if (nativeAd.starRating == null) {
			starRatingView.visibility = View.GONE
		} else {
			starRatingView.rating = nativeAd.starRating!!.toFloat()
			starRatingView.visibility = View.VISIBLE
		}

		val advertiserView = adView.advertiserView as TextView
		if (nativeAd.advertiser.isNullOrBlank()) {
			advertiserView.visibility = View.GONE
		} else {
			advertiserView.text = nativeAd.advertiser
			advertiserView.visibility = View.VISIBLE
		}

		adView.setNativeAd(nativeAd)
		return adView
	}
}