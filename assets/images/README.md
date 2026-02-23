# Image Assets

This directory contains image assets for the SpareBite app.

## Current Implementation

The login page uses high-quality open-source images from **Unsplash** (free to use, no attribution required for most uses):

1. **Background Image**: Food/sustainability themed background
   - URL: `https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&q=80`
   - Theme: Food rescue/sustainability

2. **Logo Image**: Food/restaurant themed circular logo
   - URL: `https://images.unsplash.com/photo-1504674900247-0877df9c836a?w=400&q=80`
   - Theme: Fresh food/restaurant

## To Use Local Images

If you want to use local images instead:

1. Download images from Unsplash (https://unsplash.com) or other free sources
2. Place them in this `assets/images/` directory
3. Update the image paths in `lib/screens/login.dart`:
   - Replace `Image.network(...)` with `Image.asset('assets/images/your-image.jpg')`

## Recommended Image Sources

- **Unsplash**: https://unsplash.com (Free, high-quality photos)
- **Pexels**: https://www.pexels.com (Free stock photos)
- **Pixabay**: https://pixabay.com (Free images and vectors)

## Image Themes for Food Rescue App

- Food waste reduction
- Community helping
- Fresh food/vegetables
- Sustainability
- Restaurant/food service

