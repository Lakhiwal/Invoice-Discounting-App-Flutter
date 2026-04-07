package com.example.invoice_discounting_app2;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

public class MarketplaceWidgetProvider extends AppWidgetProvider {

    private static final String PREFS_NAME = "HomeWidgetPreferences";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {

        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);

        String company = prefs.getString("company", "Company");
        String roi = prefs.getString("roi", "0");
        String days = prefs.getString("days", "0");
        String remaining = prefs.getString("remaining", "0");
        int funding = prefs.getInt("funding", 0);

        for (int appWidgetId : appWidgetIds) {

            RemoteViews views = new RemoteViews(
                    context.getPackageName(),
                    R.layout.marketplace_widget
            );

            // Fallback for missing data
            if (company == null || company.isEmpty()) company = "Marketplace";
            if (roi == null || roi.isEmpty()) roi = "0";
            if (days == null || days.isEmpty()) days = "0";
            if (remaining == null || remaining.isEmpty()) remaining = "0";

            views.setTextViewText(R.id.company, company);
            views.setTextViewText(R.id.roi, "ROI " + roi + "%");
            views.setTextViewText(R.id.days, days + " days left");
            views.setTextViewText(R.id.remaining, "₹" + remaining + " remaining");
            views.setTextViewText(R.id.funding_text, funding + "% funded");

            views.setProgressBar(R.id.funding_progress, 100, funding, false);

            // Navigation to App
            Intent intent = new Intent(context, MainActivity.class);
            intent.putExtra("open_tab", "marketplace");
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);

            PendingIntent pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
}