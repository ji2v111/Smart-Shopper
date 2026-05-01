class RegionData {
  final String code, nameEn, nameAr, currency, flag;
  const RegionData({required this.code, required this.nameEn,
      required this.nameAr, required this.currency, required this.flag});
}

const List<RegionData> kRegions = [
  RegionData(code:'SA', nameEn:'Saudi Arabia', nameAr:'السعودية',    currency:'SAR', flag:'🇸🇦'),
  RegionData(code:'AE', nameEn:'UAE',           nameAr:'الإمارات',    currency:'AED', flag:'🇦🇪'),
  RegionData(code:'KW', nameEn:'Kuwait',        nameAr:'الكويت',      currency:'KWD', flag:'🇰🇼'),
  RegionData(code:'QA', nameEn:'Qatar',         nameAr:'قطر',         currency:'QAR', flag:'🇶🇦'),
  RegionData(code:'EG', nameEn:'Egypt',         nameAr:'مصر',         currency:'EGP', flag:'🇪🇬'),
  RegionData(code:'US', nameEn:'USA',           nameAr:'أمريكا',      currency:'USD', flag:'🇺🇸'),
  RegionData(code:'GB', nameEn:'UK',            nameAr:'بريطانيا',    currency:'GBP', flag:'🇬🇧'),
  RegionData(code:'DE', nameEn:'Germany',       nameAr:'ألمانيا',     currency:'EUR', flag:'🇩🇪'),
  RegionData(code:'FR', nameEn:'France',        nameAr:'فرنسا',       currency:'EUR', flag:'🇫🇷'),
  RegionData(code:'CN', nameEn:'China',         nameAr:'الصين',       currency:'CNY', flag:'🇨🇳'),
  RegionData(code:'ES', nameEn:'Spain',         nameAr:'إسبانيا',     currency:'EUR', flag:'🇪🇸'),
  RegionData(code:'TR', nameEn:'Turkey',        nameAr:'تركيا',       currency:'TRY', flag:'🇹🇷'),
  RegionData(code:'IN', nameEn:'India',         nameAr:'الهند',       currency:'INR', flag:'🇮🇳'),
  RegionData(code:'JP', nameEn:'Japan',         nameAr:'اليابان',     currency:'JPY', flag:'🇯🇵'),
];

RegionData regionByCode(String code) =>
    kRegions.firstWhere((r) => r.code == code, orElse: () => kRegions.first);
