

# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'BBNDaily' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for BBNDaily
	pod 'FSCalendar'
	pod 'Firebase'
	pod 'InitialsImageView'
	pod 'ProgressHUD'
	pod 'BubbleTabBar'
	pod 'Firebase/Analytics'
	pod 'Firebase/Auth'
	pod 'Firebase/Core'
	pod 'Firebase/Firestore'
	pod 'Firebase/Storage'
	pod 'Firebase/Messaging'
	pod 'GoogleSignIn'
	pod 'GoogleMaps'
	pod 'SkeletonView'
	pod 'SideMenu'
  target 'BBNDailyTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'BBNDailyUITests' do
    # Pods for testing
  end

end

post_install do |installer|
    installer.generated_projects.each do |project|
        project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
            end
        end
    end
end
