# Room instantiates WorkManager's generated database by class name and its
# public no-argument constructor. R8 removed that constructor in release APKs.
-keep class androidx.work.impl.WorkDatabase_Impl { public <init>(); }
