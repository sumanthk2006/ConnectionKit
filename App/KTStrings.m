


NSString *kKTSampleSitesDirectory = @"Sample Sites";
NSString *kKTAutoOpenSampleSiteName = @"Sample Site";

// Document
NSString *kKTDocumentType = @"Sandvox Document";
NSString *kKTDocumentExtension = @"svxSite";
NSString *kKTDocumentUTI = @"com.karelia.sandvox.site-document";
NSString *kKTDocumentUTI_ORIGINAL = @"com.karelia.sandvox.document";

NSString *kKTPageIDDesignator = @"~PAGEID~";

// Spotlight metadata keys
NSString *kKTMetadataAppCreatedVersionKey = @"com_karelia_Sandvox_AppCreatedVersion"; // CFBundleVersion which created document
NSString *kKTMetadataAppLastSavedVersionKey = @"com_karelia_Sandvox_AppLastSavedVersion"; // CFBundleVersion which last saved document
NSString *kKTMetadataModelVersionKey = @"com_karelia_Sandvox_ModelVersion";


// Core Data
NSString *kKTModelVersion = @"15001";
NSString *kKTModelVersion_ORIGINAL = @"10002";
NSString *kKTModelMinimumVersion = @"10002"; // we'll support models >= this
NSString *kKTModelMaximumVersion = @"15001"; // we'll support models <= this

// DataSources
NSString *kKTDataSourceRecurse = @"kKTDataSourceRecurse";
NSString *kKTDataSourceFileName = @"kKTDataSourceFileName";
NSString *kKTDataSourceFilePath = @"kKTDataSourceFilePath";
NSString *kKTDataSourceTitle = @"kKTDataSourceTitle";
NSString *kKTDataSourceCaption = @"kKTDataSourceCaption";
NSString *kKTDataSourceURLString = @"kKTDataSourceURLString";
NSString *kKTDataSourceImageURLString = @"kKTDataSourceImageURLString";
NSString *kKTDataSourcePreferExternalImageFlag = @"kKTDataSourcePreferExternalImageFlag";
NSString *kKTDataSourceShouldIncludeLinkFlag = @"kKTDataSourceShouldIncludeLinkFlag";
NSString *kKTDataSourceLinkToOriginalFlag = @"kKTDataSourceLinkToOriginalFlag";
NSString *kKTDataSourceFeedURLString = @"kKTDataSourceFeedURLString";
NSString *kKTDataSourcePlugin = @"kKTDataSourcePlugin";
NSString *kKTDataSourceImage = @"kKTDataSourceImage";
NSString *kKTDataSourceString = @"kKTDataSourceString";
NSString *kKTDataSourceData = @"kKTDataSourceData";
NSString *kKTDataSourceUTI = @"kKTDataSourceUTI";
NSString *kKTDataSourceCreationDate = @"kKTDataSourceCreationDate";
NSString *kKTDataSourceKeywords = @"kKTDataSourceKeywords";
NSString *kKTDataSourcePasteboard = @"kKTDataSourcePasteboard";
NSString *kKTDataSourceNil = @"kKTDataSourceNil";

// Error Domains
NSString *kKTDataMigrationErrorDomain = @"com.karelia.Sandvox.DataMigrationErrorDomain";
NSString *kKTURLPrococolErrorDomain = @"com.karelia.Sandvox.GenericErrorDomain";
NSString *kKTHostSetupErrorDomain = @"com.karelia.Sandvox.HostSetupDomain";
NSString *kKTConnectionErrorDomain = @"com.karelia.Sandvox.ConnectionDomain";


// Exceptions

NSString *kKTTemplateParserException = @"KTTemplateParserException";

// KTComponents
NSString *kKTDefaultCalendarFormat = @"%Y-%m-%d %H:%M:%S %z";
NSString *kKTOutlineDraggingPboardType = @"KTOutlineDraggingPboardType";
NSString *kKTPagesPboardType = @"KTPagesPboardType";
NSString *kKTPageletsPboardType = @"KTPageletsPboardType";
NSString *kKTPagePathURLScheme = @"page";
NSString *kKTMediaNotFoundMediaName = @"KT_MediaNotFound_KT";
//NSString *kKTDocumentDefaultFileName = NSLocalizedString(@"My Site", @"default document file name");

// Plugin Extensions
NSString *kKTIndexExtension = @"svxIndex";
NSString *kKTDataSourceExtension = @"svxDataSource";
NSString *kKTElementExtension = @"svxElement";
NSString *kKTDesignExtension = @"svxDesign";

// Notifications
NSString *kKTInfoWindowMayNeedRefreshingNotification = @"KTInfoWindowMayNeedRefreshingNotification";
NSString *KTSiteStructureDidChangeNotification = @"KTSiteStructureDidChange";
NSString *kKTRootPageSavingNotification = @"KTRootPageSavingNotification";
NSString *kKTItemSelectedNotification = @"kKTItemSelectedNotification";
NSString *kKTInternalImageClassName = @"InternalImageClassName";

NSString *kKTMediaObjectDidBecomeActiveNotification = @"KTMediaObjectDidBecomeActiveNotification";
NSString *kKTMediaObjectDidBecomeInactiveNotification = @"KTMediaObjectDidBecomeInactiveNotification";
NSString *kKTDesignChangedNotification = @"kKTDesignChangedNotification";
NSString *kKTDesignWillChangeNotification = @"kKTDesignWillChangeNotification";

NSString *kKTMediaIsBeingCachedNotification = @"KTMediaIsBeingCachedNotification";

// Site Publication
NSString *kKTSourceMediaDirectory = @"SourceMedia";
NSString *kKTDefaultMediaPath = @"_Media";
NSString *kKTDefaultResourcesPath = @"_Resources";
NSString *kKTImageReplacementFolder = @"IR";

