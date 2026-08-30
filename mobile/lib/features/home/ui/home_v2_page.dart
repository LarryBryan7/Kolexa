import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../../core/widgets/notification_banner.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../notifications/ui/notification_onboarding_page.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/api/api_client.dart';
import '../../classroom/data/models/gc_models.dart';
import '../../classroom/data/repository/classroom_repository.dart';
import 'novedades_detail_page.dart';
import 'pendientes_page.dart';
import '../../../core/utils/lima_date.dart';
import 'home_docente_page.dart' show PerfilTab;
import '../../threads/ui/inbox_page.dart';

// ── Paleta extraída de Figma ──────────────────────────────
const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kChevron = Color(0xFF8E8E93);

const _kSvgClockExclamation =
    '<svg width="19" height="19" viewBox="0 0 19 19" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8.61921 16.8553H2.53947C2.06488 16.8553 1.60972 16.6667 1.27412 16.3311C0.938533 15.9955 0.75 15.5404 0.75 15.0658V4.32895C0.75 3.85435 0.938533 3.39919 1.27412 3.0636C1.60972 2.72801 2.06488 2.53947 2.53947 2.53947H13.2763C13.7509 2.53947 14.2061 2.72801 14.5417 3.0636C14.8773 3.39919 15.0658 3.85435 15.0658 4.32895V7.90789H0.75M11.4868 0.75V4.32895M4.32895 0.75V4.32895M14.1711 12.8255V14.1711L15.0658 15.0659M10.5921 14.1711C10.5921 15.1202 10.9692 16.0306 11.6404 16.7017C12.3115 17.3729 13.2219 17.75 14.1711 17.75C15.1202 17.75 16.0306 17.3729 16.7017 16.7017C17.3729 16.0306 17.75 15.1202 17.75 14.1711C17.75 13.2219 17.3729 12.3115 16.7017 11.6404C16.0306 10.9692 15.1202 10.5921 14.1711 10.5921C13.2219 10.5921 12.3115 10.9692 11.6404 11.6404C10.9692 12.3115 10.5921 13.2219 10.5921 14.1711Z" stroke="#96650C" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgCalendarWeek =
    '<svg width="17" height="17" viewBox="0 0 17 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M11.75 0.75V4.08333M4.41667 0.75V4.08333M0.75 7.41667H15.4167M3.5 9.91667H3.51192M6.25918 9.91667H6.26376M9.00918 9.91667H9.01376M11.7638 9.91667H11.7683M9.01376 12.4167H9.01835M3.50918 12.4167H3.51376M6.25918 12.4167H6.26376M0.75 4.08333C0.75 3.64131 0.943154 3.21738 1.28697 2.90482C1.63079 2.59226 2.0971 2.41667 2.58333 2.41667H13.5833C14.0696 2.41667 14.5359 2.59226 14.8797 2.90482C15.2235 3.21738 15.4167 3.64131 15.4167 4.08333V14.0833C15.4167 14.5254 15.2235 14.9493 14.8797 15.2618C14.5359 15.5744 14.0696 15.75 13.5833 15.75H2.58333C2.0971 15.75 1.63079 15.5744 1.28697 15.2618C0.943154 14.9493 0.75 14.5254 0.75 14.0833V4.08333Z" stroke="#96650C" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';
const _kNavInact = Color(0xFF707070);
const _kNavPillBg = Color(0xFFEFE8F7);
const _kNavActive = Color(0xFF391499);

const _kSvgNavHouse =
    '<svg width="15" height="16" viewBox="0 0 15 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15 7.67969V15.36C15 15.5297 14.9342 15.6925 14.8169 15.8125C14.6997 15.9326 14.5408 16 14.375 16H10C9.83424 16 9.67527 15.9326 9.55806 15.8125C9.44085 15.6925 9.375 15.5297 9.375 15.36V11.1998C9.375 11.1149 9.34208 11.0336 9.28347 10.9735C9.22487 10.9135 9.14538 10.8798 9.0625 10.8798H5.9375C5.85462 10.8798 5.77513 10.9135 5.71653 10.9735C5.65792 11.0336 5.625 11.1149 5.625 11.1998V15.36C5.625 15.5297 5.55915 15.6925 5.44194 15.8125C5.32473 15.9326 5.16576 16 5 16H0.625C0.45924 16 0.300269 15.9326 0.183058 15.8125C0.0658481 15.6925 0 15.5297 0 15.36V7.67969C0.000153664 7.34026 0.13195 7.01479 0.366406 6.77486L6.61641 0.374621C6.8508 0.134747 7.16862 0 7.5 0C7.83138 0 8.1492 0.134747 8.38359 0.374621L14.6336 6.77486C14.8681 7.01479 14.9998 7.34026 15 7.67969Z" fill="#5B4A9E"/>'
    '</svg>';

const _kSvgNavChat =
    '<svg width="17" height="17" viewBox="0 0 17 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M11.9641 6.91865C11.9641 7.16922 11.8646 7.40953 11.6875 7.58671C11.5104 7.76389 11.2703 7.86343 11.0198 7.86343H5.9839C5.73347 7.86343 5.4933 7.76389 5.31622 7.58671C5.13914 7.40953 5.03966 7.16922 5.03966 6.91865C5.03966 6.66808 5.13914 6.42778 5.31622 6.2506C5.4933 6.07342 5.73347 5.97388 5.9839 5.97388H11.0198C11.2703 5.97388 11.5104 6.07342 11.6875 6.2506C11.8646 6.42778 11.9641 6.66808 11.9641 6.91865ZM11.0198 9.12313H5.9839C5.73347 9.12313 5.4933 9.22267 5.31622 9.39985C5.13914 9.57703 5.03966 9.81734 5.03966 10.0679C5.03966 10.3185 5.13914 10.5588 5.31622 10.736C5.4933 10.9131 5.73347 11.0127 5.9839 11.0127H11.0198C11.2703 11.0127 11.5104 10.9131 11.6875 10.736C11.8646 10.5588 11.9641 10.3185 11.9641 10.0679C11.9641 9.81734 11.8646 9.57703 11.6875 9.39985C11.5104 9.22267 11.2703 9.12313 11.0198 9.12313ZM17 8.49328C17.0003 9.94978 16.6267 11.3819 15.915 12.6525C15.2032 13.923 14.1773 14.9893 12.9354 15.7492C11.6935 16.5091 10.2774 16.937 8.82277 16.992C7.36814 17.047 5.92377 16.7272 4.62813 16.0633L2.07633 16.9175C1.79854 17.0112 1.50011 17.0254 1.2147 16.9585C0.929283 16.8916 0.66822 16.7462 0.460935 16.5388C0.253649 16.3314 0.10838 16.0702 0.041502 15.7846C-0.0253764 15.499 -0.011206 15.2004 0.0824161 14.9225L0.933016 12.3692C0.348919 11.2244 0.0318046 9.96207 0.00551506 8.677C-0.0207745 7.39194 0.244445 6.11763 0.781234 4.94989C1.31802 3.78216 2.11241 2.75138 3.10467 1.93506C4.09693 1.11873 5.26124 0.538117 6.51005 0.236856C7.75887 -0.064404 9.05969 -0.0784666 10.3147 0.195726C11.5698 0.469918 12.7463 1.02523 13.756 1.81991C14.7656 2.61459 15.5821 3.62795 16.144 4.78381C16.7059 5.93967 16.9985 7.20795 17 8.49328ZM15.1115 8.49328C15.1111 7.47886 14.8775 6.47813 14.4288 5.56849C13.98 4.65886 13.3281 3.86471 12.5236 3.24748C11.719 2.63025 10.7833 2.20648 9.78886 2.00895C8.79443 1.81143 7.76791 1.84545 6.78871 2.10838C5.80952 2.3713 4.9039 2.85609 4.14191 3.52523C3.37992 4.19438 2.78199 5.02995 2.39437 5.9673C2.00674 6.90465 1.83983 7.91866 1.90652 8.93088C1.97322 9.9431 2.27174 10.9264 2.779 11.8047C2.84604 11.9205 2.88773 12.0493 2.90129 12.1824C2.91486 12.3156 2.9 12.4501 2.85769 12.5771L2.07633 14.9225L4.4204 14.1407C4.51683 14.1085 4.61777 14.0921 4.71941 14.0919C4.88524 14.0922 5.04808 14.1362 5.19153 14.2194C6.19637 14.8012 7.33663 15.1079 8.49757 15.1086C9.65851 15.1094 10.7992 14.8042 11.8048 14.2237C12.8104 13.6432 13.6454 12.808 14.2259 11.802C14.8064 10.7961 15.1119 9.65488 15.1115 8.49328Z" fill="#707070"/>'
    '</svg>';

const _kSvgNavCalendar =
    '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16.2 1.33333H14.4V1C14.4 0.734784 14.2862 0.48043 14.0837 0.292893C13.8811 0.105357 13.6064 0 13.32 0C13.0336 0 12.7589 0.105357 12.5563 0.292893C12.3538 0.48043 12.24 0.734784 12.24 1V1.33333H5.76V1C5.76 0.734784 5.64621 0.48043 5.44368 0.292893C5.24114 0.105357 4.96643 0 4.68 0C4.39357 0 4.11886 0.105357 3.91632 0.292893C3.71379 0.48043 3.6 0.734784 3.6 1V1.33333H1.8C1.32261 1.33333 0.864773 1.50893 0.527208 1.82149C0.189642 2.13405 0 2.55797 0 3V16.3333C0 16.7754 0.189642 17.1993 0.527208 17.5118C0.864773 17.8244 1.32261 18 1.8 18H16.2C16.6774 18 17.1352 17.8244 17.4728 17.5118C17.8104 17.1993 18 16.7754 18 16.3333V3C18 2.55797 17.8104 2.13405 17.4728 1.82149C17.1352 1.50893 16.6774 1.33333 16.2 1.33333ZM3.6 3.33333C3.6 3.59855 3.71379 3.8529 3.91632 4.04044C4.11886 4.22798 4.39357 4.33333 4.68 4.33333C4.96643 4.33333 5.24114 4.22798 5.44368 4.04044C5.64621 3.8529 5.76 3.59855 5.76 3.33333H12.24C12.24 3.59855 12.3538 3.8529 12.5563 4.04044C12.7589 4.22798 13.0336 4.33333 13.32 4.33333C13.6064 4.33333 13.8811 4.22798 14.0837 4.04044C14.2862 3.8529 14.4 3.59855 14.4 3.33333H15.84V5.33333H2.16V3.33333H3.6ZM2.16 16V7.33333H15.84V16H2.16ZM10.44 9.66667C10.44 9.93038 10.3555 10.1882 10.1973 10.4074C10.0391 10.6267 9.81419 10.7976 9.55106 10.8985C9.28794 10.9994 8.9984 11.0258 8.71907 10.9744C8.43974 10.9229 8.18315 10.7959 7.98177 10.6095C7.78038 10.423 7.64323 10.1854 7.58767 9.92679C7.53211 9.66815 7.56062 9.40006 7.66961 9.15642C7.7786 8.91279 7.96317 8.70455 8.19998 8.55804C8.43679 8.41153 8.71519 8.33333 9 8.33333C9.38191 8.33333 9.74818 8.47381 10.0182 8.72386C10.2883 8.97391 10.44 9.31305 10.44 9.66667ZM14.76 9.66667C14.76 9.93038 14.6755 10.1882 14.5173 10.4074C14.3591 10.6267 14.1342 10.7976 13.8711 10.8985C13.6079 10.9994 13.3184 11.0258 13.0391 10.9744C12.7597 10.9229 12.5032 10.7959 12.3018 10.6095C12.1004 10.423 11.9632 10.1854 11.9077 9.92679C11.8521 9.66815 11.8806 9.40006 11.9896 9.15642C12.0986 8.91279 12.2832 8.70455 12.52 8.55804C12.7568 8.41153 13.0352 8.33333 13.32 8.33333C13.7019 8.33333 14.0682 8.47381 14.3382 8.72386C14.6083 8.97391 14.76 9.31305 14.76 9.66667ZM6.12 13.6667C6.12 13.9304 6.03555 14.1882 5.87732 14.4074C5.71909 14.6267 5.49419 14.7976 5.23106 14.8985C4.96794 14.9994 4.6784 15.0258 4.39907 14.9744C4.11974 14.9229 3.86315 14.7959 3.66177 14.6095C3.46038 14.423 3.32323 14.1854 3.26767 13.9268C3.21211 13.6681 3.24062 13.4001 3.34961 13.1564C3.4586 12.9128 3.64317 12.7045 3.87998 12.558C4.11679 12.4115 4.3952 12.3333 4.68 12.3333C5.06191 12.3333 5.42818 12.4738 5.69823 12.7239C5.96829 12.9739 6.12 13.313 6.12 13.6667ZM10.44 13.6667C10.44 13.9304 10.3555 14.1882 10.1973 14.4074C10.0391 14.6267 9.81419 14.7976 9.55106 14.8985C9.28794 14.9994 8.9984 15.0258 8.71907 14.9744C8.43974 14.9229 8.18315 14.7959 7.98177 14.6095C7.78038 14.423 7.64323 14.1854 7.58767 13.9268C7.53211 13.6681 7.56062 13.4001 7.66961 13.1564C7.7786 12.9128 7.96317 12.7045 8.19998 12.558C8.43679 12.4115 8.71519 12.3333 9 12.3333C9.38191 12.3333 9.74818 12.4738 10.0182 12.7239C10.2883 12.9739 10.44 13.313 10.44 13.6667ZM14.76 13.6667C14.76 13.9304 14.6755 14.1882 14.5173 14.4074C14.3591 14.6267 14.1342 14.7976 13.8711 14.8985C13.6079 14.9994 13.3184 15.0258 13.0391 14.9744C12.7597 14.9229 12.5032 14.7959 12.3018 14.6095C12.1004 14.423 11.9632 14.1854 11.9077 13.9268C11.8521 13.6681 11.8806 13.4001 11.9896 13.1564C12.0986 12.9128 12.2832 12.7045 12.52 12.558C12.7568 12.4115 13.0352 12.3333 13.32 12.3333C13.7019 12.3333 14.0682 12.4738 14.3382 12.7239C14.6083 12.9739 14.76 13.313 14.76 13.6667Z" fill="#707070"/>'
    '</svg>';

const _kSvgNavUser =
    '<svg width="17" height="16" viewBox="0 0 17 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15.9251 14.1038C14.9075 12.3179 13.3186 10.9263 11.4141 10.1531C12.3612 9.4428 13.0608 8.45249 13.4138 7.32248C13.7668 6.19246 13.7553 4.98002 13.3809 3.8569C13.0065 2.73379 12.2883 1.75693 11.3279 1.06471C10.3674 0.372492 9.21359 0 8.02972 0C6.84585 0 5.69199 0.372492 4.73159 1.06471C3.77118 1.75693 3.05292 2.73379 2.67855 3.8569C2.30418 4.98002 2.29267 6.19246 2.64567 7.32248C2.99866 8.45249 3.69825 9.4428 4.64534 10.1531C2.74083 10.9263 1.1519 12.3179 0.134328 14.1038C0.0712758 14.2052 0.0292516 14.3182 0.0107541 14.4362C-0.00774351 14.5541 -0.00233692 14.6746 0.0266525 14.7904C0.0556419 14.9062 0.107622 15.015 0.179503 15.1103C0.251385 15.2057 0.341699 15.2856 0.445078 15.3453C0.548456 15.405 0.662789 15.4434 0.781278 15.458C0.899767 15.4727 1.01999 15.4634 1.13481 15.4306C1.24963 15.3979 1.35669 15.3424 1.44964 15.2675C1.54258 15.1925 1.61951 15.0997 1.67585 14.9944C3.0207 12.6699 5.3957 11.2835 8.02972 11.2835C10.6637 11.2835 13.0387 12.6706 14.3836 14.9944C14.5057 15.1907 14.6993 15.3319 14.9236 15.388C15.1479 15.4442 15.3852 15.4109 15.5854 15.2952C15.7856 15.1796 15.933 14.9906 15.9964 14.7683C16.0598 14.5459 16.0342 14.3076 15.9251 14.1038ZM4.17034 5.64285C4.17034 4.87954 4.39669 4.13337 4.82077 3.4987C5.24484 2.86403 5.84759 2.36936 6.5528 2.07725C7.25801 1.78515 8.034 1.70872 8.78265 1.85763C9.53129 2.00655 10.219 2.37412 10.7587 2.91386C11.2985 3.4536 11.666 4.14128 11.8149 4.88992C11.9639 5.63857 11.8874 6.41456 11.5953 7.11977C11.3032 7.82498 10.8085 8.42773 10.1739 8.8518C9.5392 9.27588 8.79303 9.50223 8.02972 9.50223C7.00651 9.50105 6.02555 9.09406 5.30203 8.37054C4.57851 7.64702 4.17152 6.66606 4.17034 5.64285Z" fill="#707070"/>'
    '</svg>';

// Variantes "bold/fill" (activo) y "regular/outline" (inactivo) de Phosphor,
// exportadas directamente de Figma para cada ícono del nav.
const _kSvgNavHouseOutline =
    '<svg width="16" height="17" viewBox="0 0 16 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15.5312 7.01686L9.1312 0.47858C8.83116 0.172145 8.42426 0 8 0C7.57574 0 7.16885 0.172145 6.8688 0.47858L0.468808 7.01686C0.319629 7.16833 0.201373 7.34855 0.120899 7.54707C0.0404244 7.74559 -0.000666939 7.95845 8.18596e-06 8.17332V16.0193C8.18596e-06 16.2794 0.101151 16.5288 0.281185 16.7127C0.46122 16.8967 0.7054 17 0.960007 17H6.08C6.33461 17 6.57879 16.8967 6.75882 16.7127C6.93886 16.5288 7.04 16.2794 7.04 16.0193V11.7694H8.96V16.0193C8.96 16.2794 9.06114 16.5288 9.24118 16.7127C9.42121 16.8967 9.66539 17 9.92 17H15.04C15.2946 17 15.5388 16.8967 15.7188 16.7127C15.8989 16.5288 16 16.2794 16 16.0193V8.17332C16.0007 7.95845 15.9596 7.74559 15.8791 7.54707C15.7986 7.34855 15.6804 7.16833 15.5312 7.01686ZM14.08 15.0385H10.88V10.7886C10.88 10.5285 10.7789 10.2791 10.5988 10.0951C10.4188 9.91122 10.1746 9.80789 9.92 9.80789H6.08C5.82539 9.80789 5.58121 9.91122 5.40118 10.0951C5.22115 10.2791 5.12 10.5285 5.12 10.7886V15.0385H1.92001V8.30817L8 2.0968L14.08 8.30817V15.0385Z" fill="#707070"/>'
    '</svg>';

const _kSvgNavChatFill =
    '<svg width="17" height="17" viewBox="0 0 17 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8.5 0C6.24642 0.00247486 4.08585 0.898803 2.49233 2.49233C0.898803 4.08585 0.00247486 6.24642 0 8.5V15.64C0 16.0007 0.143285 16.3466 0.398335 16.6017C0.653384 16.8567 0.999306 17 1.36 17H8.5C10.7543 17 12.9163 16.1045 14.5104 14.5104C16.1045 12.9163 17 10.7543 17 8.5C17 6.24566 16.1045 4.08365 14.5104 2.48959C12.9163 0.895533 10.7543 0 8.5 0ZM11.22 10.88H5.44C5.25965 10.88 5.08669 10.8084 4.95917 10.6808C4.83164 10.5533 4.76 10.3803 4.76 10.2C4.76 10.0197 4.83164 9.84669 4.95917 9.71917C5.08669 9.59164 5.25965 9.52 5.44 9.52H11.22C11.4003 9.52 11.5733 9.59164 11.7008 9.71917C11.8284 9.84669 11.9 10.0197 11.9 10.2C11.9 10.3803 11.8284 10.5533 11.7008 10.6808C11.5733 10.8084 11.4003 10.88 11.22 10.88ZM11.22 8.16H5.44C5.25965 8.16 5.08669 8.08836 4.95917 7.96083C4.83164 7.83331 4.76 7.66035 4.76 7.48C4.76 7.29965 4.83164 7.12669 4.95917 6.99917C5.08669 6.87164 5.25965 6.8 5.44 6.8H11.22C11.4003 6.8 11.5733 6.87164 11.7008 6.99917C11.8284 7.12669 11.9 7.29965 11.9 7.48C11.9 7.66035 11.8284 7.83331 11.7008 7.96083C11.5733 8.08836 11.4003 8.16 11.22 8.16Z" fill="#5B4A9E"/>'
    '</svg>';

const _kSvgNavCalendarFill =
    '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16.5 1.38462H14.25V0.692308C14.25 0.508696 14.171 0.332605 14.0303 0.202772C13.8897 0.0729393 13.6989 0 13.5 0C13.3011 0 13.1103 0.0729393 12.9697 0.202772C12.829 0.332605 12.75 0.508696 12.75 0.692308V1.38462H5.25V0.692308C5.25 0.508696 5.17098 0.332605 5.03033 0.202772C4.88968 0.0729393 4.69891 0 4.5 0C4.30109 0 4.11032 0.0729393 3.96967 0.202772C3.82902 0.332605 3.75 0.508696 3.75 0.692308V1.38462H1.5C1.10218 1.38462 0.720644 1.53049 0.43934 1.79016C0.158035 2.04983 0 2.40201 0 2.76923V16.6154C0 16.9826 0.158035 17.3348 0.43934 17.5945C0.720644 17.8541 1.10218 18 1.5 18H16.5C16.8978 18 17.2794 17.8541 17.5607 17.5945C17.842 17.3348 18 16.9826 18 16.6154V2.76923C18 2.40201 17.842 2.04983 17.5607 1.79016C17.2794 1.53049 16.8978 1.38462 16.5 1.38462ZM4.875 14.5385C4.6525 14.5385 4.43499 14.4776 4.24998 14.3634C4.06498 14.2493 3.92078 14.0872 3.83564 13.8974C3.75049 13.7076 3.72821 13.4988 3.77162 13.2974C3.81502 13.096 3.92217 12.9109 4.0795 12.7657C4.23684 12.6205 4.43729 12.5216 4.65552 12.4815C4.87375 12.4414 5.09995 12.462 5.30552 12.5406C5.51109 12.6192 5.68679 12.7523 5.8104 12.9231C5.93402 13.0938 6 13.2946 6 13.5C6 13.7754 5.88147 14.0396 5.6705 14.2343C5.45952 14.4291 5.17337 14.5385 4.875 14.5385ZM9 14.5385C8.7775 14.5385 8.55999 14.4776 8.37498 14.3634C8.18998 14.2493 8.04578 14.0872 7.96064 13.8974C7.87549 13.7076 7.85321 13.4988 7.89662 13.2974C7.94002 13.096 8.04717 12.9109 8.2045 12.7657C8.36184 12.6205 8.56229 12.5216 8.78052 12.4815C8.99875 12.4414 9.22495 12.462 9.43052 12.5406C9.63609 12.6192 9.81179 12.7523 9.9354 12.9231C10.059 13.0938 10.125 13.2946 10.125 13.5C10.125 13.7754 10.0065 14.0396 9.79549 14.2343C9.58452 14.4291 9.29837 14.5385 9 14.5385ZM9 11.0769C8.7775 11.0769 8.55999 11.016 8.37498 10.9019C8.18998 10.7878 8.04578 10.6256 7.96064 10.4359C7.87549 10.2461 7.85321 10.0373 7.89662 9.83587C7.94002 9.63443 8.04717 9.44939 8.2045 9.30416C8.36184 9.15893 8.56229 9.06002 8.78052 9.01995C8.99875 8.97988 9.22495 9.00045 9.43052 9.07905C9.63609 9.15765 9.81179 9.29075 9.9354 9.46152C10.059 9.6323 10.125 9.83307 10.125 10.0385C10.125 10.3139 10.0065 10.578 9.79549 10.7728C9.58452 10.9675 9.29837 11.0769 9 11.0769ZM13.125 14.5385C12.9025 14.5385 12.685 14.4776 12.5 14.3634C12.315 14.2493 12.1708 14.0872 12.0856 13.8974C12.0005 13.7076 11.9782 13.4988 12.0216 13.2974C12.065 13.096 12.1722 12.9109 12.3295 12.7657C12.4868 12.6205 12.6873 12.5216 12.9055 12.4815C13.1238 12.4414 13.35 12.462 13.5555 12.5406C13.7611 12.6192 13.9368 12.7523 14.0604 12.9231C14.184 13.0938 14.25 13.2946 14.25 13.5C14.25 13.7754 14.1315 14.0396 13.9205 14.2343C13.7095 14.4291 13.4234 14.5385 13.125 14.5385ZM13.125 11.0769C12.9025 11.0769 12.685 11.016 12.5 10.9019C12.315 10.7878 12.1708 10.6256 12.0856 10.4359C12.0005 10.2461 11.9782 10.0373 12.0216 9.83587C12.065 9.63443 12.1722 9.44939 12.3295 9.30416C12.4868 9.15893 12.6873 9.06002 12.9055 9.01995C13.1238 8.97988 13.35 9.00045 13.5555 9.07905C13.7611 9.15765 13.9368 9.29075 14.0604 9.46152C14.184 9.6323 14.25 9.83307 14.25 10.0385C14.25 10.3139 14.1315 10.578 13.9205 10.7728C13.7095 10.9675 13.4234 11.0769 13.125 11.0769ZM16.5 5.53846H1.5V2.76923H3.75V3.46154C3.75 3.64515 3.82902 3.82124 3.96967 3.95107C4.11032 4.08091 4.30109 4.15385 4.5 4.15385C4.69891 4.15385 4.88968 4.08091 5.03033 3.95107C5.17098 3.82124 5.25 3.64515 5.25 3.46154V2.76923H12.75V3.46154C12.75 3.64515 12.829 3.82124 12.9697 3.95107C13.1103 4.08091 13.3011 4.15385 13.5 4.15385C13.6989 4.15385 13.8897 4.08091 14.0303 3.95107C14.171 3.82124 14.25 3.64515 14.25 3.46154V2.76923H16.5V5.53846Z" fill="#5B4A9E"/>'
    '</svg>';

const _kSvgNavUserFill =
    '<svg width="17" height="16" viewBox="0 0 17 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15.9478 15.1508C15.8937 15.2449 15.8158 15.3229 15.722 15.3772C15.6283 15.4315 15.5219 15.46 15.4137 15.46H0.61594C0.507763 15.4599 0.401518 15.4312 0.307876 15.3769C0.214233 15.3226 0.136488 15.2445 0.082447 15.1506C0.0284063 15.0566 -2.77521e-05 14.95 2.03251e-08 14.8415C2.77927e-05 14.733 0.0285164 14.6265 0.0826052 14.5325C1.2564 12.4975 3.06527 11.0383 5.17626 10.3465C4.13207 9.72316 3.3208 8.77328 2.86704 7.64278C2.41327 6.51228 2.3421 5.26366 2.66446 4.08867C2.98681 2.91368 3.68487 1.87729 4.65142 1.13866C5.61798 0.400032 6.7996 0 8.01481 0C9.23002 0 10.4116 0.400032 11.3782 1.13866C12.3447 1.87729 13.0428 2.91368 13.3652 4.08867C13.6875 5.26366 13.6163 6.51228 13.1626 7.64278C12.7088 8.77328 11.8975 9.72316 10.8534 10.3465C12.9643 11.0383 14.7732 12.4975 15.947 14.5325C16.0012 14.6265 16.0299 14.733 16.03 14.8416C16.0301 14.9501 16.0018 15.0568 15.9478 15.1508Z" fill="#5B4A9E"/>'
    '</svg>';
const _kSwitchSec = Color(0xFFB4AFC8);

// ── Datos de un hijo ──────────────────────────────────────
class _Child {
  final String studentId;
  final String initials;
  final String fullName;
  final String? section;
  final int? age;
  final String? avatarUrl;
  const _Child({
    required this.studentId,
    required this.initials,
    required this.fullName,
    this.section,
    this.age,
    this.avatarUrl,
  });
}

// Tono "presionado" de una card: en vez del gris plano por defecto de
// Material (que no combina con cards de color propio, ej. el ámbar de
// "Urgente para hoy"), desatura y oscurece levemente el color base de
// CADA card para usarlo como splash/highlight de su InkWell — así el
// estado seleccionado se ve como una versión grisácea del color
// original, no un gris genérico sin relación con la tarjeta.
Color _pressedTint(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withSaturation((hsl.saturation * 0.65).clamp(0.0, 1.0))
      .withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0))
      .toColor()
      .withValues(alpha: 0.35);
}

// Feedback de "presionado" hecho a mano (sin InkWell): el fade interno
// de Material no se puede afinar (entra y sale con el mismo timing
// fijo), y el toque se sentía poco "limpio". Acá se controla el propio
// estado con TapDown/TapUp/TapCancel: entra rápido (100ms) y sale más
// lento (350ms), para que el tinte se sienta un poco más sostenido en
// vez de desaparecer de golpe al soltar.
class _PressTint extends StatefulWidget {
  final Widget child;
  final Color tintColor;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const _PressTint({
    required this.child,
    required this.tintColor,
    required this.borderRadius,
    this.onTap,
  });

  @override
  State<_PressTint> createState() => _PressTintState();
}

class _PressTintState extends State<_PressTint> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Por defecto GestureDetector solo responde donde hay contenido
      // "opaco" debajo (deferToChild) — deja zonas muertas en paddings
      // y espacios vacíos. InkWell, en cambio, cubre TODA el área del
      // widget; con `opaque` igualamos ese comportamiento.
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      // Un solo AnimatedContainer envolviendo el contenido (nada de
      // Stack): así el ancho/alto siguen viniendo del padre y del
      // propio contenido exactamente igual que un Container normal —
      // un Stack (con StackFit.loose o .expand) rompía el centrado o
      // el alto automático de la tarjeta.
      child: AnimatedContainer(
        // Al presionar: cambio INSTANTÁNEO (sin transición) — el
        // usuario tiene que ver de inmediato que está seleccionando
        // algo, sin esperar ningún fade. Se mantiene fijo mientras
        // sigue tocando. Recién al soltar se anima (350ms) la salida.
        duration: Duration(milliseconds: _pressed ? 0 : 350),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _pressed ? widget.tintColor : widget.tintColor.withValues(alpha: 0),
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}

String _initials(String first, String last) {
  final f = first.isNotEmpty ? first[0].toUpperCase() : '';
  final l = last.isNotEmpty ? last[0].toUpperCase() : '';
  return '$f$l';
}

// Tareas del resto de la semana (de mañana en adelante, sin contar
// hoy) — mismo criterio usado por la tarjeta/tab "Esta semana" en
// varios lugares (Home y el tab Semana de PendientesPage).
List<GcCoursework> _filterRestOfWeek(List<GcCoursework> all) {
  final today = limaToday();
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  final restOfWeekStart = today.add(const Duration(days: 1));
  return all.where((cw) {
    if (cw.dueDate == null) return false;
    final d = limaDay(cw.dueDate!);
    return !d.isBefore(restOfWeekStart) && !d.isAfter(weekEnd);
  }).toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
}

// ─────────────────────────────────────────────────────────
class HomeV2Page extends StatefulWidget {
  /// Nombre del alumno que llega al tocar una notificación de asistencia.
  /// Se usa para preseleccionar al hijo correcto en el switcher.
  final String? initialStudentName;
  const HomeV2Page({super.key, this.initialStudentName});

  @override
  State<HomeV2Page> createState() => _HomeV2PageState();
}

class _HomeV2PageState extends State<HomeV2Page> with WidgetsBindingObserver {
  int _selectedChild = 0;
  int _navIndex = 0;
  int _refreshKey = 0;
  bool _wentToClassroomBrowser = false;
  bool _waitingClassroomConfirm = false;
  bool _connectingClassroom = false;
  // Mejora D: guarda de reentrada para que pull-to-refresh, el resume por
  // notificación FCM o el post-frame inicial no lancen syncs duplicados.
  bool _refreshing = false;
  // El botón manual "Ya autoricé, verificar" solo aparece si el flujo
  // automático (didChangeAppLifecycleState) no detecta el regreso del
  // navegador dentro del tiempo de respaldo.
  bool _showManualVerify = false;
  Timer? _verifyTimeout;
  Future<bool>? _classroomStatusFuture;
  // Estado de conexión a Classroom conocido de forma síncrona (bool?).
  // Se actualiza cuando resuelve `_classroomStatusFuture` (isConnected) y se
  // usa para que el card "Esta semana" se muestre en estado de carga junto al
  // de "Novedades" desde el inicio, sin esperar a /parent/home.
  bool? _classroomConnected;
  // Estado de conexión recordado por alumno (persistido en SharedPreferences).
  // Permite saber de forma síncrona si un hijo está conectado a Classroom al
  // entrar al Home o al cambiar de hijo, sin esperar a isConnected ni a
  // /parent/home. Clave = studentId.
  final Map<String, bool> _knownConnected = {};
  // Datos combinados del home del padre (todaySummary + upcomingStatus) en
  // UNA sola petición. Ambos cards ("Novedades" y "Esta semana") comparten
  // este resultado, evitando que compitan por la única conexión del pooler
  // (connection_limit=1) y se serialicen (~1.9s por query).
  ParentHomeData? _parentHome;

  // Marca de tiempo del montaje del Home para medir cuánto tarda en
  // cargarse el primer /parent/home (instrumentación [FLOW]).
  late final int _homeStartMs;

  @override
  void initState() {
    super.initState();
    _homeStartMs = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addObserver(this);
    // Cargamos (rápido, la instancia ya está cacheada por auth) el estado de
    // conexión recordado por alumno, para que el card "Esta semana" pueda
    // mostrarse en estado de carga junto al de "Novedades" desde el primer
    // frame en la segunda entrada (cuando ya no hace falta conectar Classroom).
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        for (final c in _buildChildren(authState)) {
          final v = p.getBool(_gcConnectedKey(c.studentId));
          if (v != null) {
            _knownConnected[c.studentId] = v;
          }
        }
        // Sembramos el estado de conexión del hijo actual de forma síncrona.
        final children = _buildChildren(authState);
        if (children.isNotEmpty) {
          final sid = children[_selectedChild.clamp(0, children.length - 1)].studentId;
          final known = _knownConnected[sid];
          // Mejora A: la card "Conectar Google Classroom" se muestra/oculta de
          // forma determinista desde el primer frame (sin depender de GET
          // /status): true si recordamos conectado, false en caso contrario.
          setState(() {
            if (known != null) _classroomConnected = known;
            _classroomStatusFuture = Future.value(known ?? false);
          });
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _onRefresh();
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        // Si venimos de una notificación de un alumno concreto,
        // preseleccionar a ese hijo en el switcher.
        final targetName = widget.initialStudentName;
        if (targetName != null && targetName.isNotEmpty) {
          final children = _buildChildren(authState);
          final idx = children.indexWhere((c) =>
              c.fullName.toLowerCase().contains(targetName.toLowerCase()));
          if (idx >= 0) {
            _selectedChild = idx;
            if (mounted) setState(() {});
          }
        }
        await maybeShowNotificationOnboarding(context, authState.user);
        await maybeShowAutostartReminder(context);
      }
    });
  }

  @override
  void dispose() {
    _verifyTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToClassroomBrowser) {
      setState(() => _wentToClassroomBrowser = false);
      // Volvimos del navegador de Google Classroom. Recién AHORA activamos el
      // estado de verificación/carga ("Estamos cargando tus tareas...") y
      // sincronizamos, porque el usuario ya aceptó (o no) los permisos.
      // No llamamos a _onRefresh en paralelo para que la card de conexión no
      // reaparezca brevemente con un estado de conexión desactualizado.
      _verifyClassroomConnection();
    }
  }

  void _switchChild(int index) {
    setState(() {
      _selectedChild = index;
      // Limpiar los datos del hijo anterior para no mostrar datos cruzados.
      _parentHome = null;
    });
    final authState = context.read<AuthBloc>().state;
    final children = _buildChildren(authState);
    if (children.isNotEmpty) {
      final studentId = children[index.clamp(0, children.length - 1)].studentId;
      // Mejora A: estado de conexión 100% síncrono (_knownConnected persistido),
      // sin GET /status. La reconciliación con el backend la hace
      // _loadParentHome vía upcomingStatus.connected.
      final known = _knownConnected[studentId] ?? false;
      setState(() {
        _classroomConnected = known;
        _classroomStatusFuture = Future.value(known);
      });
      _loadParentHome(studentId);
    }
  }

  String? _currentStudentId() {
    final authState = context.read<AuthBloc>().state;
    final children = _buildChildren(authState);
    if (children.isEmpty) return null;
    return children[_selectedChild.clamp(0, children.length - 1)].studentId;
  }

  String _gcConnectedKey(String studentId) => 'gc_connected_$studentId';

  /// Guarda el estado de conexión conocido para este alumno: en memoria para
  /// lectura síncrona inmediata y persistido en SharedPreferences para la
  /// próxima entrada.
  void _rememberConnected(String studentId, bool connected) {
    _knownConnected[studentId] = connected;
    SharedPreferences.getInstance().then((p) {
      p.setBool(_gcConnectedKey(studentId), connected);
    });
  }

  // force: true SOLO para el pull-to-refresh manual (el usuario deslizó
  // pidiendo datos frescos) — salta la caché de 15 min del sync con Google.
  // La carga automática (initState, resume de la app) deja force=false para
  // no pagar el sync completo (~26-30s) en cada apertura normal.
  Future<void> _onRefresh({bool showErrors = false, bool force = false}) async {
    // Mejora D: guarda de reentrada. Si ya hay un refresh en vuelo (pull-to-
    // refresh + resume por FCM + post-frame inicial), se ignora la llamada.
    if (_refreshing) return;
    _refreshing = true;
    try {
      final authState = context.read<AuthBloc>().state;
      final children = _buildChildren(authState);
      if (children.isNotEmpty) {
        final studentId = children[_selectedChild.clamp(0, children.length - 1)].studentId;
        final api = context.read<ApiClient>();
        final repo = ClassroomRepository(api);
        // 1er /parent/home: trae upcomingStatus.connected (fuente de verdad del
        // backend). La decisión de sync ya NO depende de _knownConnected (que
        // puede no estar poblado por la carrera con SharedPreferences).
        final home = await _loadParentHome(studentId);
        if (!mounted) return;
        final connected = home?.upcomingStatus.connected ?? false;
        // Sincronizamos la card "Conectar" de forma determinista con el dato
        // del servidor (redundante con _loadParentHome, pero explícito).
        setState(() {
          _classroomStatusFuture = Future.value(connected);
          _classroomConnected = connected;
        });
        // El sync solo tiene sentido si el alumno está conectado a Google
        // Classroom (según el backend). Si no lo está, se omite.
        if (connected) {
          try {
            final result = await repo.sync(studentId, force: force);
            // Mejora C: si el sync fue cache hit (no trajo datos nuevos de
            // Google), la primera carga de /parent/home ya es suficiente y
            // evitamos el segundo /parent/home redundante. Solo recargamos
            // si el sync realmente trajo datos nuevos (cache miss).
            if (!result.cacheHit) {
              await _loadParentHome(studentId);
            }
          } catch (_) {
            // Sync falla silenciosamente — los datos locales siguen cargando.
          }
        }
      } else {
        setState(() => _refreshKey++);
      }
    } finally {
      _refreshing = false;
    }
  }

  /// Carga los datos combinados del home del padre en UNA sola petición.
  /// `_NovedadesCard` y `_EstaSemanRow` consumen este resultado compartido.
  Future<ParentHomeData?> _loadParentHome(String studentId) async {
    try {
      final repo = ClassroomRepository(context.read<ApiClient>());
      final data = await repo.getParentHome(studentId);
      if (!mounted) return null;
      setState(() {
        _parentHome = data;
        _refreshKey++;
        // Mejora A: fuente de verdad de connected = upcomingStatus.connected
        // (la misma petición). Auto-corrige un _knownConnected desactualizado
        // (p. ej. token revocado en otro dispositivo) sin GET /status.
        final serverConnected = data.upcomingStatus.connected;
        if (serverConnected != _classroomConnected) {
          _classroomConnected = serverConnected;
          _classroomStatusFuture = Future.value(serverConnected);
        }
      });
      if (data.upcomingStatus.connected != _knownConnected[studentId]) {
        _rememberConnected(studentId, data.upcomingStatus.connected);
      }
      print('[FLOW] home-to-first-data = '
          '${DateTime.now().millisecondsSinceEpoch - _homeStartMs} ms');
      return data;
    } catch (_) {
      // Error de red: mantener los datos anteriores sin romper la UI.
      return null;
    }
  }

  Future<void> _connectClassroom() async {
    final studentId = _currentStudentId();
    if (studentId == null) return;
    // Evita doble toque: deshabilita el botón mientras se procesa.
    if (_connectingClassroom) return;
    setState(() => _connectingClassroom = true);
    try {
      final url = await ClassroomRepository(context.read<ApiClient>()).getAuthUrl(studentId);
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el navegador')),
        );
        return;
      }
      if (mounted) {
        // Marcamos que fuimos al navegador de Google. NO activamos
        // _waitingClassroomConfirm aquí: el mensaje "Estamos cargando tus
        // tareas..." SOLO debe aparecer DESPUÉS de volver del navegador y
        // haber aceptado los permisos (ver didChangeAppLifecycleState →
        // _verifyClassroomConnection), nunca antes de ir al navegador.
        _wentToClassroomBrowser = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingClassroom = false);
    }
  }

  Future<void> _verifyClassroomConnection() async {
    final studentId = _currentStudentId();
    if (studentId == null) return;
    // Evita doble toque: deshabilita el botón mientras se procesa.
    if (_connectingClassroom) return;
    // El flujo automático (o el manual) ya se disparó: cancelamos el timer de
    // respaldo para que NO muestre el botón manual mientras verificamos.
    _verifyTimeout?.cancel();
    _verifyTimeout = null;
    final api = context.read<ApiClient>();
    final repo = ClassroomRepository(api);
    // Mantenemos el estado "Verificando conexión..." mientras se sincroniza.
    if (mounted) {
      setState(() {
        _connectingClassroom = true;
        _waitingClassroomConfirm = true;
        _showManualVerify = false;
      });
    }
    // Verificamos REALMENTE si el usuario autorizó los permisos al volver del
    // navegador. isConnected consulta el backend (devuelve true solo si hay
    // token guardado). Esto cubre el caso en que el usuario vuelve SIN aceptar
    // permisos (canceló): en ese caso NO debe marcarse como conectado.
    bool connected = false;
    try {
      connected = await repo.isConnected(studentId);
    } catch (_) {
      connected = false;
    }
    if (!mounted) return;
    if (!connected) {
      // El usuario NO autorizó (canceló o volvió sin aceptar): NO marcamos el
      // alumno como conectado. Dejamos el estado en "no conectado" para que el
      // home vuelva a mostrar la card "Conectar Google Classroom" (botón
      // "Conectar con Google") y NO la card "Esta semana".
      setState(() {
        _connectingClassroom = false;
        _waitingClassroomConfirm = false;
        _showManualVerify = false;
        _classroomStatusFuture = Future.value(false);
        _classroomConnected = false;
      });
      _rememberConnected(studentId, false);
      return;
    }
    // El usuario SÍ autorizó: sincronizamos ANTES de mostrar la card "Esta
    // semana" para que el conteo de pendientes ya incluya los datos recién
    // traídos de Google.
    try { await repo.sync(studentId); } catch (_) {}
    if (!mounted) return;
    // Mantenemos "Estamos cargando tus tareas..." visible (waitingConfirm=true)
    // mientras cargamos los datos combinados del home. Así el card "Esta
    // semana" aparece YA con el conteo real ("N tareas" o "sin pendientes") y
    // NO muestra "Sin pendientes" ni "Cargando tus tareas..." brevemente antes
    // de actualizarse.
    await _loadParentHome(studentId);
    if (!mounted) return;
    setState(() {
      _connectingClassroom = false;
      _waitingClassroomConfirm = false;
      _showManualVerify = false;
      _classroomStatusFuture = Future.value(true);
      _classroomConnected = true;
    });
    // Persistimos el estado de conexión para la próxima entrada.
    _rememberConnected(studentId, true);
  }

  void _selectChild(int index) {
    setState(() {
      _selectedChild = index;
      // Limpiar los datos del hijo anterior para no mostrar datos cruzados
      // mientras cargan los del hijo recién seleccionado.
      _parentHome = null;
    });
    // Recalcular el estado de conexión de Classroom del hijo recién
    // seleccionado para que la card de conectar se muestre/oculte bien.
    final authState = context.read<AuthBloc>().state;
    final children = _buildChildren(authState);
    if (children.isNotEmpty) {
      final studentId = children[index.clamp(0, children.length - 1)].studentId;
      // Mejora A: estado de conexión 100% síncrono (_knownConnected persistido),
      // sin GET /status. La reconciliación con el backend la hace
      // _loadParentHome vía upcomingStatus.connected.
      final known = _knownConnected[studentId] ?? false;
      setState(() {
        _classroomConnected = known;
        _classroomStatusFuture = Future.value(known);
      });
      // Cargar los datos combinados del nuevo hijo.
      _loadParentHome(studentId);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '¡Buenos días';
    if (h < 19) return '¡Buenas tardes';
    return '¡Buenas noches';
  }

  List<_Child> _buildChildren(AuthState state) {
    if (state is AuthAuthenticated && state.user.children.isNotEmpty) {
      return state.user.children
          .map((c) => _Child(
                studentId: c.id.toString(),
                initials: _initials(c.firstName, c.lastName),
                fullName: c.fullName,
                section: c.section,
                age: c.age,
                avatarUrl: c.avatarUrl,
              ))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Screen size: ${MediaQuery.of(context).size}');
    final authState = context.read<AuthBloc>().state;
    final firstName =
        authState is AuthAuthenticated ? authState.user.firstName : '';
    final parentAvatarUrl =
        authState is AuthAuthenticated ? authState.user.avatar : null;
    final parentInitials = authState is AuthAuthenticated
        ? _initials(authState.user.firstName, authState.user.lastName)
        : '';
    final children = _buildChildren(authState);
    final safeIndex =
        children.isEmpty ? 0 : _selectedChild.clamp(0, children.length - 1);

    final now = DateTime.now();
    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final dateStr =
        '${days[now.weekday - 1]} ${now.day} de ${months[now.month - 1]}';
    final sizes = Theme.of(context).extension<AppSizes>()!;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Contenido scrollable ───────────────────────
            // Tope de ancho: a partir de 600dp (breakpoint de tablet de
            // Android WindowSizeClass) el contenido deja de estirarse y
            // se centra, en vez de romper el layout de las tarjetas.
            Expanded(
              // El contenido cruza en fade al cambiar de pestaña, en vez de
              // cortarse de golpe — al mismo ritmo que la animación del nav.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _navIndex == 3
                  ? const PerfilTab(key: ValueKey('perfil'))
                  : _navIndex == 1
                  ? const InboxPage(key: ValueKey('inbox'))
                  : RefreshIndicator(
                key: const ValueKey('home'),
                color: _kPrimary,
                onRefresh: () => _onRefresh(force: true),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        sizes.cardPadding, 19, sizes.cardPadding, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Banner: notificaciones desactivadas ──
                        // Se muestra si el usuario apagó las notificaciones
                        // desde Ajustes (nivel WhatsApp).
                        const NotificationBanner(),
                        const SizedBox(height: 12),

                        // ── Header: saludo + switcher ──────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_greeting()}, $firstName!',
                                      style: TextStyle(
                                        fontSize: sizes.titleHorizontal,
                                        fontWeight: FontWeight.w700,
                                        color: _kTextDark,
                                      )),
                                  const SizedBox(height: 4),
                                  Text(dateStr,
                                      style: TextStyle(
                                        fontSize: sizes.textFecha,
                                        color: _kTextGray,
                                      )),
                                ],
                              ),
                            ),
                            // Con un solo hijo no hay nada entre qué elegir
                            // — en vez del switcher (pensado para 2+ hijos,
                            // con círculo secundario y badge) se muestra la
                            // foto de perfil de Google del padre.
                            if (children.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: _ChildSwitcher(
                                  children: children,
                                  selectedIndex: safeIndex,
                                  onSelect: _selectChild,
                                ),
                              )
                            else if (children.length == 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: _AvatarCircle(
                                  initials: parentInitials,
                                  size: sizes.childSwitcherCircle,
                                  avatarUrl: parentAvatarUrl,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 13),

                        // ── Card: datos del hijo ───────────────
                        if (children.isNotEmpty) ...[
                          _ChildInfoCard(
                            child: children[safeIndex],
                            onTap: () => _showChildPicker(children, safeIndex),
                          ),
                          const SizedBox(height: 12),

                          // ── Card: urgente para hoy ─────────────
                          // Tareas de Classroom que vencen hoy — mismo dato
                          // ya cargado por /parent/home, sin petición extra.
                          _UrgentCard(
                            tasksToday: (_parentHome?.upcomingStatus.upcoming ?? [])
                                .where((cw) =>
                                    cw.dueDate != null &&
                                    limaDay(cw.dueDate!) == limaToday())
                                .toList(),
                            // Resto de la semana (sin contar hoy) — mismo
                            // criterio que la tarjeta "Esta semana".
                            weekTasks: _filterRestOfWeek(
                                _parentHome?.upcomingStatus.upcoming ?? []),
                            studentName: children[safeIndex].fullName,
                          ),
                          const SizedBox(height: 12),

                          // ── Card: novedades de hoy ─────────────
                          // Recibe el summary del estado padre (cargado por
                          // /parent/home en UNA sola petición) y un callback
                          // para refrescar. Ya no hace su propia llamada.
                          _NovedadesCard(
                            child: children[safeIndex],
                            dateLabel: dateStr,
                            summary: _parentHome?.todaySummary,
                            onRefresh: () => _loadParentHome(
                                children[safeIndex].studentId),
                          ),
                          const SizedBox(height: 12),

                          // ── Row: esta semana ───────────────────
                          // Recibe el upcomingStatus del estado padre
                          // (cargado por /parent/home en la misma petición
                          // que las novedades). Ya no hace su propia llamada,
                          // evitando que ambos cards compitan por la única
                          // conexión del pooler.
                          Column(
                            children: [
                              _EstaSemanRow(
                                child: children[safeIndex],
                                refreshKey: _refreshKey,
                                upcomingStatus: _parentHome?.upcomingStatus,
                                // Estado de conexión conocido de forma
                                // síncrona (isConnected): permite que el card
                                // se muestre en estado de carga junto al de
                                // "Novedades" desde el inicio, sin esperar a
                                // /parent/home.
                                connected: _classroomConnected,
                                // Mientras la card "Conectar Google Classroom"
                                // muestra "Estamos cargando tus tareas...", el
                                // card "Esta semana" se oculta para no mostrar
                                // 2 cards a la vez.
                                waitingConfirm: _waitingClassroomConfirm,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),

                          // ── Card: conectar Google Classroom ─────
                          // Solo se muestra si el alumno aún no ha
                          // vinculado su cuenta de Google.
                          FutureBuilder<bool>(
                            future: _classroomStatusFuture,
                            builder: (context, snap) {
                              final connected = snap.data ?? true;
                              // Mientras se está verificando la conexión
                              // (_waitingClassroomConfirm), la card debe seguir
                              // visible mostrando "Estamos cargando" para no
                              // dejar un hueco vacío antes de que aparezca
                              // "Esta semana".
                              if (connected && !_waitingClassroomConfirm) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  _ClassroomConnectCardParent(
                                    childName: children[safeIndex].fullName,
                                    waitingConfirm: _waitingClassroomConfirm,
                                    connecting: _connectingClassroom,
                                    showManualVerify: _showManualVerify,
                                    onConnect: _connectClassroom,
                                    onVerify: _verifyClassroomConnection,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),

                        ],

                        // ── Accesos rápidos ────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text('Accesos Rápidos',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kTextDark)),
                            ),
                            const Text('Ver todo',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary)),
                            const SizedBox(width: 4),
                            const Text('›',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: _kPrimary)),
                            const SizedBox(width: 16),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const _AccesosRapidos(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
              ),
            ),

            // ── Bottom Nav (fijo) ──────────────────────────
            _BottomNav(
              selected: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ],
        ),
      ),
    );
  }

  void _showChildPicker(List<_Child> children, int currentIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecciona un hijo',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark)),
            const SizedBox(height: 16),
            ...children.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final selected = i == currentIndex;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _AvatarCircle(
                    initials: c.initials,
                    size: 40,
                    color: selected ? _kPrimary : _kSwitchSec,
                    avatarUrl: c.avatarUrl),
                title: Text(c.fullName,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: _kTextDark,
                    )),
                subtitle: c.section != null
                    ? Text(
                        c.age != null
                            ? '${c.section} · ${c.age} años'
                            : c.section!,
                        style: const TextStyle(color: _kTextGray, fontSize: 12),
                      )
                    : null,
                trailing: selected
                    ? const Icon(Icons.check_circle, color: _kPrimary)
                    : null,
                onTap: () {
                  _switchChild(i);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Child Switcher animado
// Al tocar, el círculo frontal (36×36) y el trasero (28×28)
// intercambian posición, tamaño y color con animación suave.
// Al terminar notifica al padre para avanzar _selectedChild.
// ─────────────────────────────────────────────────────────
class _ChildSwitcher extends StatelessWidget {
  final List<_Child> children;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ChildSwitcher({
    required this.children,
    required this.selectedIndex,
    required this.onSelect,
  });

  void _openSheet(BuildContext context) {
    if (children.length < 2) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDD8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Seleccionar hijo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF888099),
                    ),
                  ),
                ),
              ),
              ...children.asMap().entries.map((e) {
                final i = e.key;
                final child = e.value;
                final isSelected = i == selectedIndex;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: _AvatarCircle(
                    initials: child.initials,
                    size: 40,
                    color: isSelected ? _kPrimary : _kSwitchSec,
                    fontSize: 15,
                    avatarUrl: child.avatarUrl,
                  ),
                  title: Text(
                    child.fullName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _kPrimary : const Color(0xFF1A0F3A),
                    ),
                  ),
                  subtitle: child.section != null
                      ? Text(child.section!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888099)))
                      : null,
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: _kPrimary, size: 20)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(i);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final selIdx = selectedIndex;
    final nextIdx = (selIdx + 1) % children.length;
    final hasMore = children.length > 2;
    final extra = children.length - 2;
    final sizes = Theme.of(context).extension<AppSizes>()!;

    final ratio = sizes.childSwitcherCircle / 36.0;
    final circleBig = sizes.childSwitcherCircle;
    final circleSmall = 28.0 * ratio;
    final boxWidth = 52.0 * ratio;
    final boxHeight = 40.0 * ratio;
    final fontBig = 12.0 * ratio;
    final fontSmall = 10.0 * ratio;
    final badgeFont = 9.0 * ratio;
    final badgeSize = 15.0 * ratio;
    final offsetX = 24.0 * ratio;
    final offsetY = 4.0 * ratio;

    return Material(
      color: Colors.transparent,
      child: InkWell(
      borderRadius: BorderRadius.circular(boxHeight / 2),
      onTap: () => _openSheet(context),
      child: SizedBox(
        width: boxWidth,
        height: boxHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Círculo secundario (atrás)
            Positioned(
              left: offsetX,
              top: offsetY,
              child: _AvatarCircle(
                initials: children[nextIdx].initials,
                size: circleSmall,
                color: _kSwitchSec,
                fontSize: fontSmall,
                avatarUrl: children[nextIdx].avatarUrl,
              ),
            ),
            // Círculo activo (adelante) con borde
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBg, width: 2),
                ),
                child: _AvatarCircle(
                  initials: children[selIdx].initials,
                  size: circleBig,
                  color: _kPrimary,
                  fontSize: fontBig,
                  avatarUrl: children[selIdx].avatarUrl,
                ),
              ),
            ),
            // Badge: coordenadas exactas del diseño Figma (27, 25) en frame 52×40
            if (children.length >= 2)
              Positioned(
                left: 27.0 * ratio,
                top: 25.0 * ratio,
                child: hasMore
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBg, width: 1.5),
                        ),
                        child: Text('+$extra',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: badgeFont,
                                fontWeight: FontWeight.w700)),
                      )
                    : Container(
                        width: badgeSize,
                        height: badgeSize,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kBg, width: 1.5),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: badgeSize * 0.8,
                        ),
                      ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: info del hijo seleccionado
// ─────────────────────────────────────────────────────────
class _ChildInfoCard extends StatelessWidget {
  final _Child child;
  final VoidCallback onTap;
  const _ChildInfoCard({required this.child, required this.onTap});

  static const _kMenuText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _kTextDark,
  );

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          _AvatarCircle(
            initials: child.initials,
            size: sizes.avatarLarge,
            fontSize: sizes.avatarLarge / 55 * 16,
            avatarUrl: child.avatarUrl,
            color: const Color(0xFFD4C9F0),
            textColor: _kPrimary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.fullName,
                    style: TextStyle(
                        fontSize: sizes.textNombreHijo,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: _kTextDark)),
                if (child.section != null || child.age != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (child.section != null) 'Sección ${child.section!}',
                      if (child.age != null) '${child.age} años',
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: sizes.textSubtitulo,
                        height: 1.0,
                        color: _kTextGray),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: _kChevron, size: 26),
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black26,
            constraints: const BoxConstraints(minWidth: 180),
            onSelected: (value) {},
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'archivo',
                height: 44,
                child: Row(
                  children: [
                    Icon(Icons.history, color: _kPrimary, size: 20),
                    SizedBox(width: 10),
                    Text('Archivo de días', style: _kMenuText),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'editar',
                height: 44,
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/ic_edit_perfil.svg',
                      width: 20,
                      colorFilter: const ColorFilter.mode(_kPrimary, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 10),
                    const Text('Editar perfil', style: _kMenuText),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'horario',
                height: 44,
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: _kPrimary, size: 20),
                    SizedBox(width: 10),
                    Text('Ver horario', style: _kMenuText),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: novedades de hoy (llegada · ahora · fotos)
// ─────────────────────────────────────────────────────────
class _NovedadesCard extends StatefulWidget {
  final _Child child;
  final String dateLabel;
  /// Resumen de hoy compartido desde el estado padre (cargado por
  /// /parent/home en la misma petición que "Esta semana").
  final TodaySummary? summary;
  /// Callback para refrescar los datos desde el padre.
  final VoidCallback onRefresh;
  const _NovedadesCard({
    required this.child,
    required this.dateLabel,
    required this.summary,
    required this.onRefresh,
  });

  @override
  State<_NovedadesCard> createState() => _NovedadesCardState();
}

class _NovedadesCardState extends State<_NovedadesCard>
    with WidgetsBindingObserver {
  // Copia local del summary para poder recalcular el "Ahora" cada 30s sin
  // tocar la red. Se sincroniza con widget.summary cuando el padre refresca.
  TodaySummary? _summary;
  bool _initialized = false;
  Timer? _scheduleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startAutoRefresh();
    }
  }

  @override
  void didUpdateWidget(_NovedadesCard old) {
    super.didUpdateWidget(old);
    // Cambió el hijo: limpiar los datos del hijo anterior para no mostrar
    // datos cruzados mientras cargan los del nuevo.
    if (old.child.studentId != widget.child.studentId) {
      setState(() => _summary = null);
    }
    // El padre refrescó los datos (FCM, resume, sync): sincronizamos la
    // copia local. Si ya tenemos datos locales con el "Ahora" recalculado,
    // conservamos el currentCourse actualizado.
    if (old.summary != widget.summary && widget.summary != null) {
      setState(() {
        _summary = widget.summary;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Si el padre ya tiene datos cargados (p. ej. al cambiar de hijo),
    // usarlos de inmediato en lugar de mostrar el estado de carga.
    _summary = widget.summary;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleTimer?.cancel();
    // Des-suscribir para no dejar referencias colgadas.
    PushNotificationsService.instance.removeDataRefreshListener(_handleDataRefresh);
    super.dispose();
  }

  // ── Auto-refresh en tiempo real ──────────────────────────
  // 1) FCM data message: el backend envía `refresh: true` cuando se
  //    registra asistencia o se suben fotos → refresca desde el padre.
  // 2) Timer local: recalcula el bloque de horario activo cada 30s
  //    para que el "Ahora" cambie de clase sin tocar la red.
  // 3) Al volver de background (resume) → refresca por si hubo cambios.
  void _startAutoRefresh() {
    PushNotificationsService.instance.addDataRefreshListener(_handleDataRefresh);
    _scheduleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recalculateSchedule();
    });
  }

  void _handleDataRefresh(Map<String, dynamic> data) {
    if (!mounted) return;
    widget.onRefresh();
  }

  // Recalcula el curso activo ("Ahora") desde los bloques de horario
  // ya cargados, comparando con la hora actual. No requiere red.
  void _recalculateSchedule() {
    final blocks = _summary?.scheduleBlocks;
    if (blocks == null || blocks.isEmpty) return;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    String? activeCourse;
    for (final b in blocks) {
      final start = _toMinutes(b.startTime);
      final end = _toMinutes(b.endTime);
      if (nowMinutes >= start && nowMinutes < end) {
        if (b.type == 'class') activeCourse = b.courseName;
        break;
      }
    }

    final newCourse = activeCourse ?? '–';
    if (_summary!.currentCourse != newCourse) {
      setState(() {
        _summary = TodaySummary(
          arrivalStatus: _summary!.arrivalStatus,
          arrivalTime: _summary!.arrivalTime,
          currentCourse: newCourse,
          photoCount: _summary!.photoCount,
          photoUrls: _summary!.photoUrls,
          scheduleBlocks: _summary!.scheduleBlocks,
        );
      });
    }
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleDataRefresh(const {});
    }
  }

  void _openDetail() {
    if (_summary == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovedadesDetailPage(
          summary: _summary!,
          childName: widget.child.fullName,
          dateLabel: widget.dateLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    // No se usa _Card aquí (a diferencia de _ChildInfoCard, que sí):
    // el fondo blanco necesita quedar POR FUERA del InkWell para que el
    // ripple no quede tapado — _Card lo pone como hijo, así que se
    // replica su mismo look (radius 20, padding 16) a mano.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _PressTint(
        borderRadius: BorderRadius.circular(20),
      tintColor: _pressedTint(Colors.white),
      onTap: _openDetail,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Resumen del día',
                    style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark)),
                const Text('›',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _kChevron)),
              ],
            ),
            const SizedBox(height: 16),
            // Fuente de verdad: `_summary` (se sincroniza con el summary del
            // padre, que se actualiza por FCM data message, refresh on resume
            // y tras el sync). Mientras carga, mostramos placeholders.
            if (_summary == null)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_llegada.svg',
                    label: 'Llegada',
                    value: 'Cargando...',
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_ahora.svg',
                    label: 'Ahora',
                    value: '–',
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_fotos.svg',
                    label: 'Fotos',
                    value: '–',
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_llegada.svg',
                    label: 'Llegada',
                    value: _summary!.arrivalLabel,
                    valueColor: _summary!.arrivalStatus == 'present'
                        ? const Color(0xFF1F6B44)
                        : _summary!.arrivalStatus == 'late'
                            ? const Color(0xFF96650C)
                            : _summary!.arrivalStatus == 'absent'
                                ? Colors.red[700]
                                : _summary!.arrivalStatus == 'justified'
                                    ? const Color(0xFF5B4A9E)
                                    : _kTextGray,
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_ahora.svg',
                    label: 'Ahora',
                    value: _summary!.currentCourse ?? '–',
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_fotos.svg',
                    label: 'Fotos',
                    value: _summary!.photoLabel,
                  ),
                ],
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: conectar Google Classroom del hijo (padre)
// ─────────────────────────────────────────────────────────
class _ClassroomConnectCardParent extends StatelessWidget {
  final String childName;
  final bool waitingConfirm;
  final bool connecting;
  final bool showManualVerify;
  final VoidCallback onConnect;
  final VoidCallback onVerify;

  const _ClassroomConnectCardParent({
    required this.childName,
    required this.waitingConfirm,
    required this.connecting,
    required this.showManualVerify,
    required this.onConnect,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimaryLt, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_outlined, color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conecta Google Classroom',
                      style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vincula la cuenta de $childName para ver sus tareas y novedades',
                      style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Estado: esperando confirmación del navegador o verificando ──
          // Mientras se espera el regreso del navegador o se sincronizan las
          // tareas, NO mostramos botones: solo un mensaje de espera claro.
          if (waitingConfirm) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    showManualVerify
                        ? 'No pudimos verificar automáticamente'
                        : 'Estamos cargando tus tareas, un momento por favor...',
                    style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray),
                  ),
                ),
              ],
            ),
            // Si el flujo automático no detecta el regreso del navegador,
            // mostramos el botón manual como respaldo.
            if (showManualVerify) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: connecting ? null : onVerify,
                  icon: connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kPrimary),
                        )
                      : const Icon(Icons.verified_outlined,
                          size: 16, color: _kPrimary),
                  label: Text(
                    connecting ? 'Verificando...' : 'Ya autoricé, verificar',
                    style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: BorderSide(
                        color: connecting ? const Color(0xFF6F60AA) : _kPrimary),
                    disabledForegroundColor: const Color(0xFF6F60AA),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ] else ...[
            // ── Estado: botón "Conectar con Google" ──
            // Mientras se prepara la conexión (esperando la URL del navegador)
            // ocultamos el botón y mostramos un mensaje de espera.
            if (connecting) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Preparando la conexión...',
                    style: TextStyle(
                        fontSize: sizes.textLabelCard, color: _kTextGray),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.link, size: 16, color: Colors.white),
                  label: Text(
                    'Conectar con Google',
                    style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _NovedadItem extends StatelessWidget {
  final String? iconAsset;
  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _NovedadItem({
    this.iconAsset,
    this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: sizes.circleIconNovedades,
            height: sizes.circleIconNovedades,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F9E3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: sizes.glyphNovedades, color: const Color(0xFF145D10))
                : SvgPicture.asset(
                    iconAsset!,
                    width: sizes.glyphNovedades,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF145D10), BlendMode.srcIn),
                  ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: sizes.textLabelCard,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF145D10))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: sizes.textValueCard,
              fontWeight: FontWeight.w400,
              color: valueColor ?? _kTextGray,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Modelo interno de ítem pendiente (extensible a pagos, etc.)
// ─────────────────────────────────────────────────────────
enum _PendingType { tarea, pago }

class _PendingItem {
  final _PendingType type;
  final String title;
  final String subtitle;
  final DateTime? dueDate;
  final String? workType; // 'ASSIGNMENT' | 'SHORT_ANSWER_QUESTION' | 'MULTIPLE_CHOICE_QUESTION'

  const _PendingItem({
    required this.type,
    required this.title,
    required this.subtitle,
    this.dueDate,
    this.workType,
  });
}

// ─────────────────────────────────────────────────────────
// Card: pendientes (tareas de Classroom; pagos cuando esté listo)
// Muestra máx 3 ítems; si hay más, el 3ro muestra "y N más" al costado.
// Si solo hay tareas, el header lo indica con "ver solo tareas →".
// ─────────────────────────────────────────────────────────
class _PendientesCard extends StatefulWidget {
  final String studentId;
  const _PendientesCard({super.key, required this.studentId});

  @override
  State<_PendientesCard> createState() => _PendientesCardState();
}

class _PendientesCardState extends State<_PendientesCard> {
  late Future<List<_PendingItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(_PendientesCard old) {
    super.didUpdateWidget(old);
    if (old.studentId != widget.studentId) {
      setState(() => _future = _load());
    }
  }

  Future<List<_PendingItem>> _load() async {
    if (widget.studentId.isEmpty) return [];
    try {
      final upcoming = await ClassroomRepository(context.read<ApiClient>())
          .getUpcoming(widget.studentId);
      final items = upcoming
          .map((cw) => _PendingItem(
                type: _PendingType.tarea,
                title: cw.title,
                subtitle: cw.courseName,
                dueDate: cw.dueDate,
                workType: cw.workType,
              ))
          .toList();
      // Cuando haya pagos: añadirlos aquí y reordenar por dueDate
      return items;
    } catch (e) {
      debugPrint('[PendientesCard] getUpcoming error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;

    return _Card(
      radius: 16,
      child: FutureBuilder<List<_PendingItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final onlyTareas = items.every((i) => i.type == _PendingType.tarea);
          final visible = items.take(5).toList();
          final extra = items.length - visible.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera ─────────────────────────────────
              Row(
                children: [
                  Text(
                    'Pendientes',
                    style: TextStyle(
                      fontSize: sizes.textValueCard,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    ),
                  ),
                  const Spacer(),
                  if (items.isNotEmpty && onlyTareas)
                    Text(
                      'ver tareas →',
                      style: TextStyle(
                        fontSize: sizes.textLabelCard,
                        color: _kPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text('›',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _kChevron)),
                ],
              ),

              // ── Estado vacío ──────────────────────────────
              if (!snapshot.hasData) ...[
                const SizedBox(height: 14),
                const SizedBox(
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kPrimary),
                    ),
                  ),
                ),
              ] else if (items.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Sin pendientes esta semana',
                  style: TextStyle(
                      fontSize: sizes.textLabelCard, color: _kTextGray),
                ),
              ] else ...[
                const SizedBox(height: 4),
                ...visible.asMap().entries.map((e) {
                  final isLast = e.key == visible.length - 1;
                  return _PendienteRow(
                    item: e.value,
                    showDivider: !isLast,
                    extraCount: isLast ? extra : 0,
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Fila individual de ítem pendiente
// ─────────────────────────────────────────────────────────
class _PendienteRow extends StatelessWidget {
  final _PendingItem item;
  final bool showDivider;
  final int extraCount;

  const _PendienteRow({
    required this.item,
    this.showDivider = true,
    this.extraCount = 0,
  });

  String _fmtDue(DateTime d) {
    final local = d.toLocal();
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${local.day} ${months[local.month]}';
  }

  IconData get _icon {
    if (item.type == _PendingType.pago) return Icons.credit_card_outlined;
    switch (item.workType) {
      case 'SHORT_ANSWER_QUESTION':
      case 'MULTIPLE_CHOICE_QUESTION':
        return Icons.quiz_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 13, color: _kPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w600,
                        color: _kTextDark,
                      ),
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: sizes.textLabelCard, color: _kTextGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.dueDate != null)
                Text(
                  _fmtDue(item.dueDate!),
                  style: TextStyle(
                      fontSize: sizes.textLabelCard, color: _kTextGray),
                ),
              if (extraCount > 0) ...[
                const SizedBox(width: 6),
                Text(
                  'y $extraCount más',
                  style: TextStyle(
                    fontSize: sizes.textLabelCard,
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0EFF4)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Accesos rápidos (2 filas × 3)
// ─────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────
// Card: urgente para hoy (ámbar)
// ─────────────────────────────────────────────────────────
class _UrgentCard extends StatelessWidget {
  final List<GcCoursework> tasksToday;
  final List<GcCoursework> weekTasks;
  final String studentName;

  const _UrgentCard({
    required this.tasksToday,
    required this.weekTasks,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    // El fondo de color va en un Container por FUERA del InkWell (no
    // dentro) — si fuera al revés, ese fondo opaco se pintaría ENCIMA
    // del ripple y lo taparía por completo, dejándolo invisible.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF0DD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFAD973), width: 1.2),
      ),
      child: _PressTint(
        borderRadius: BorderRadius.circular(20),
      // Ámbar más saturado que el fondo (que es un crema muy pálido) —
      // así el "presionado" se ve como un ámbar apagado, no gris puro.
      tintColor: _pressedTint(const Color(0xFFFAD973)),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => PendientesPage(
            studentName: studentName,
            todayTasks: tasksToday,
            weekTasks: weekTasks,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF6E0AB),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.string(
                _kSvgClockExclamation,
                width: 17,
                colorFilter:
                    const ColorFilter.mode(Color(0xFF96650C), BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Urgente para hoy',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF693902))),
                  const SizedBox(height: 1),
                  Text(
                    tasksToday.isEmpty
                        ? 'Sin tareas urgentes hoy'
                        : tasksToday.length == 1
                            ? '1 tarea vence hoy'
                            : '${tasksToday.length} tareas vencen hoy',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF693902)),
                  ),
                ],
              ),
            ),
            const Text('›',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF693902))),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Row: esta semana (resumen semanal)
// ─────────────────────────────────────────────────────────
class _EstaSemanRow extends StatefulWidget {
  final _Child child;
  final int refreshKey;
  /// upcomingStatus compartido desde el estado padre (cargado por
  /// /parent/home en la misma petición que "Novedades").
  final UpcomingStatus? upcomingStatus;
  /// Estado de conexión a Classroom conocido de forma síncrona (isConnected).
  /// Permite mostrar el card en estado de carga ("Cargando tus tareas...")
  /// junto al de "Novedades" desde el inicio, sin esperar a /parent/home.
  final bool? connected;
  /// Mientras la card "Conectar Google Classroom" muestra "Estamos cargando
  /// tus tareas..." (verificación tras volver del navegador), el card "Esta
  /// semana" NO debe aparecer para evitar mostrar 2 cards a la vez.
  final bool waitingConfirm;
  const _EstaSemanRow({
    required this.child,
    required this.refreshKey,
    required this.upcomingStatus,
    this.connected,
    this.waitingConfirm = false,
  });

  @override
  State<_EstaSemanRow> createState() => _EstaSemanRowState();
}

class _EstaSemanRowState extends State<_EstaSemanRow> {
  int? _count;
  List<GcCoursework>? _items;
  bool? _connected;

  @override
  void initState() {
    super.initState();
    _applyStatus(widget.upcomingStatus);
  }

  @override
  void didUpdateWidget(_EstaSemanRow old) {
    super.didUpdateWidget(old);
    // Recalcular cuando cambia el hijo, el home se refresca o llegan datos
    // nuevos del padre (p. ej. al volver de conectar Google Classroom).
    if (old.child.studentId != widget.child.studentId) {
      // Cambió el hijo: limpiar los datos del hijo anterior para no mostrar
      // datos cruzados mientras cargan los del nuevo.
      setState(() {
        _count = null;
        _items = null;
        _connected = null;
      });
    }
    if (old.child.studentId != widget.child.studentId ||
        old.refreshKey != widget.refreshKey ||
        old.upcomingStatus != widget.upcomingStatus) {
      _applyStatus(widget.upcomingStatus);
    }
  }

  // Deriva el conteo semanal desde el upcomingStatus compartido. No hace
  // ninguna llamada de red propia: los datos vienen de /parent/home.
  void _applyStatus(UpcomingStatus? status) {
    if (status == null) {
      // Aún no hay datos: mantener el estado de carga.
      if (_count == null && _connected == null) return;
      return;
    }
    final all = status.upcoming;
    setState(() {
      _connected = status.connected;
      _count = _filterRestOfWeek(all).length;
      _items = all;
    });
  }

  String get _subtitle {
    if (_count == null) return 'Cargando tus tareas...';
    if (_count == 0) return 'Sin pendientes';
    return '$_count tarea${_count != 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    // REQUISITO (UX): el card "Esta semana" SOLO debe verse cuando el alumno
    // está conectado a Google Classroom. Si NO está conectado, no debe
    // aparecer en ningún momento (ni siquiera en estado de carga).
    //
    // La fuente canónica es `_connected` (viene de /parent/home). Mientras
    // /parent/home aún no responde (_connected == null), usamos el estado de
    // conexión conocido de forma síncrona (widget.connected, de isConnected)
    // para que el card aparezca en estado de carga JUNTO al de "Novedades"
    // desde el inicio, sin esperar a /parent/home — pero ÚNICAMENTE si ese
    // estado conocido es `true` (conectado).
    //
    // Además, mientras la card "Conectar Google Classroom" está mostrando
    // "Estamos cargando tus tareas..." (widget.waitingConfirm == true, durante
    // la verificación tras volver del navegador), este card NO debe aparecer
    // para evitar mostrar 2 cards a la vez.
    final showCard = !widget.waitingConfirm &&
        (_connected == true || (widget.connected == true && _connected == null));
    if (!showCard) return const SizedBox.shrink();
    // El fondo blanco va en un Container por FUERA del InkWell — si
    // fuera adentro, taparía el ripple por completo (queda invisible).
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _PressTint(
        borderRadius: BorderRadius.circular(20),
      tintColor: _pressedTint(Colors.white),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          // EstaSemanPage se eliminó — su contenido pasó al tab "Semana"
          // de PendientesPage. Reutilizamos la lista ya cargada en el
          // home para que la página abra al instante, sin otra llamada.
          builder: (_) => PendientesPage(
            studentName: widget.child.fullName,
            initialTab: RangoTab.semana,
            todayTasks: (_items ?? [])
                .where((cw) =>
                    cw.dueDate != null && limaDay(cw.dueDate!) == limaToday())
                .toList(),
            weekTasks: _filterRestOfWeek(_items ?? []),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFFDEED3),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.string(
                _kSvgCalendarWeek,
                width: 16,
                colorFilter:
                    const ColorFilter.mode(Color(0xFF96650C), BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Esta semana',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF693902))),
                  const SizedBox(height: 1),
                  Text(_subtitle,
                      style: const TextStyle(fontSize: 13, color: _kTextGray)),
                ],
              ),
            ),
            // Mientras carga, mostramos un spinner pequeño (Figma no muestra
            // badge numérico: el conteo va incluido en el subtítulo).
            if (_count == null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF96650C)),
              ),
            const SizedBox(width: 4),
            const Text('›',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF693902))),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _AccesosRapidos extends StatelessWidget {
  const _AccesosRapidos();

  static const _items = [
    (Icons.calendar_month_outlined, 'Calendario'),
    (Icons.photo_library_outlined,  'Fotos'),
    (Icons.bar_chart_rounded,       'Progreso'),
  ];

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Row(
      children: _items.map((i) => _buildItem(context, i, sizes)).toList(),
    );
  }

  Widget _buildItem(BuildContext context, (IconData, String) item, AppSizes sizes) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _PressTint(
          borderRadius: BorderRadius.circular(16),
          tintColor: _pressedTint(Colors.white),
          // TODO: sin destino todavía — solo feedback visual al tocar.
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Container(
                    width: sizes.circleIconAccesos,
                    height: sizes.circleIconAccesos,
                    decoration: const BoxDecoration(
                      color: _kPrimaryLt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, size: sizes.glyphAccesos, color: _kPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(item.$2,
                      style: TextStyle(
                          fontSize: sizes.textLabelAccesos, color: _kTextDark)),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom Nav
// ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selected, required this.onTap});

  // (ícono outline/inactivo, ícono fill/activo, label)
  static const _items = [
    (_kSvgNavHouseOutline, _kSvgNavHouse, 'Inicio'),
    (_kSvgNavChat, _kSvgNavChatFill, 'Chats'),
    (_kSvgNavCalendar, _kSvgNavCalendarFill, 'Calendario'),
    (_kSvgNavUser, _kSvgNavUserFill, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SizedBox(
              height: 64,
              child: Row(
                children: _items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  final active = i == selected;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // El pill "crece" desde el centro al activarse
                              // (efecto resorte), en vez de aparecer de golpe.
                              AnimatedScale(
                                scale: active ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutBack,
                                child: Container(
                                  width: sizes.iconBottomNav + 24,
                                  height: sizes.iconBottomNav + 8,
                                  decoration: BoxDecoration(
                                    color: _kNavPillBg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              // El ícono da un saltito al activarse, en el
                              // mismo tiempo que crece el pill de fondo.
                              AnimatedScale(
                                scale: active ? 1.0 : 0.86,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutBack,
                                child: SvgPicture.string(
                                  active ? item.$2 : item.$1,
                                  width: sizes.iconBottomNav,
                                  height: sizes.iconBottomNav,
                                  colorFilter: ColorFilter.mode(
                                    active ? _kNavActive : _kNavInact,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(item.$3,
                              style: TextStyle(
                                fontSize: sizes.textLabelBottomNav,
                                fontWeight:
                                    active ? FontWeight.w600 : FontWeight.w400,
                                color: active ? _kNavActive : _kNavInact,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Widgets reutilizables
// ─────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  const _Card({required this.child, this.onTap, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initials;
  final double size;
  final Color color;
  final Color textColor;
  final double fontSize;
  final String? avatarUrl;

  const _AvatarCircle({
    required this.initials,
    required this.size,
    this.color = _kPrimary,
    this.textColor = Colors.white,
    this.fontSize = 14,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return ClipOval(
        child: avatarUrl!.startsWith('assets/')
            ? Image.asset(
                avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : Image.network(
                avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}
