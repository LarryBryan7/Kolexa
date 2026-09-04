// ============================================================
// home_docente_page.dart — Home del docente (v1)
// ============================================================
// Primera versión, portada 1:1 desde el frame de Figma
// "06 — Inicio Docente v1". Usa el mismo sistema de tamaños
// responsivo (AppSizes) y el mismo tope de ancho de 600dp que
// el Home del padre — ver home_v2_page.dart para el patrón base.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../../core/widgets/notification_banner.dart';
import '../../../core/widgets/press_tint.dart';
import '../../notifications/ui/notification_onboarding_page.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../teachers/data/teacher_repository.dart';
import 'package:image_picker/image_picker.dart';
import '../../attendance/ui/attendance_page.dart';
import '../../threads/data/inbox_sync_service.dart';
import '../../threads/ui/inbox_page.dart';

// ── Paleta (compartida con el Home del padre) ─────────────
const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kChevron = Color(0xFF8E8E93);
const _kNavInact = Color(0xFF707070);
const _kNavPillBg = Color(0xFFF3E6FF);
const _kNavActive = Color(0xFF972FFF);
const _kSuccessText = Color(0xFF1F6B44);
const _kAmber = Color(0xFF96650C);
const _kNavBadge = Color(0xFF9F6CF3);

// ── Paleta propia del aviso "plan semanal" ────────────────
const _kBannerBg = Color(0xFFFAEED3);
const _kBannerText = Color(0xFF693902);

// Iconos Phosphor "bold/fill" (activo) y "regular/outline" (inactivo) del
// nav inferior, exportados de Figma (mismo set que el nav del padre).
const _kSvgNavHouseOutline =
    '<svg width="16" height="17" viewBox="0 0 16 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15.5312 7.01686L9.1312 0.47858C8.83116 0.172145 8.42426 0 8 0C7.57574 0 7.16885 0.172145 6.8688 0.47858L0.468808 7.01686C0.319629 7.16833 0.201373 7.34855 0.120899 7.54707C0.0404244 7.74559 -0.000666939 7.95845 8.18596e-06 8.17332V16.0193C8.18596e-06 16.2794 0.101151 16.5288 0.281185 16.7127C0.46122 16.8967 0.7054 17 0.960007 17H6.08C6.33461 17 6.57879 16.8967 6.75882 16.7127C6.93886 16.5288 7.04 16.2794 7.04 16.0193V11.7694H8.96V16.0193C8.96 16.2794 9.06114 16.5288 9.24118 16.7127C9.42121 16.8967 9.66539 17 9.92 17H15.04C15.2946 17 15.5388 16.8967 15.7188 16.7127C15.8989 16.5288 16 16.2794 16 16.0193V8.17332C16.0007 7.95845 15.9596 7.74559 15.8791 7.54707C15.7986 7.34855 15.6804 7.16833 15.5312 7.01686ZM14.08 15.0385H10.88V10.7886C10.88 10.5285 10.7789 10.2791 10.5988 10.0951C10.4188 9.91122 10.1746 9.80789 9.92 9.80789H6.08C5.82539 9.80789 5.58121 9.91122 5.40118 10.0951C5.22115 10.2791 5.12 10.5285 5.12 10.7886V15.0385H1.92001V8.30817L8 2.0968L14.08 8.30817V15.0385Z" fill="#707070"/>'
    '</svg>';

const _kSvgNavHouseFill =
    '<svg width="15" height="16" viewBox="0 0 15 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15 7.67969V15.36C15 15.5297 14.9342 15.6925 14.8169 15.8125C14.6997 15.9326 14.5408 16 14.375 16H10C9.83424 16 9.67527 15.9326 9.55806 15.8125C9.44085 15.6925 9.375 15.5297 9.375 15.36V11.1998C9.375 11.1149 9.34208 11.0336 9.28347 10.9735C9.22487 10.9135 9.14538 10.8798 9.0625 10.8798H5.9375C5.85462 10.8798 5.77513 10.9135 5.71653 10.9735C5.65792 11.0336 5.625 11.1149 5.625 11.1998V15.36C5.625 15.5297 5.55915 15.6925 5.44194 15.8125C5.32473 15.9326 5.16576 16 5 16H0.625C0.45924 16 0.300269 15.9326 0.183058 15.8125C0.0658481 15.6925 0 15.5297 0 15.36V7.67969C0.000153664 7.34026 0.13195 7.01479 0.366406 6.77486L6.61641 0.374621C6.8508 0.134747 7.16862 0 7.5 0C7.83138 0 8.1492 0.134747 8.38359 0.374621L14.6336 6.77486C14.8681 7.01479 14.9998 7.34026 15 7.67969Z" fill="#5B4A9E"/>'
    '</svg>';

const _kSvgNavChatOutline =
    '<svg width="17" height="17" viewBox="0 0 17 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M11.9641 6.91865C11.9641 7.16922 11.8646 7.40953 11.6875 7.58671C11.5104 7.76389 11.2703 7.86343 11.0198 7.86343H5.9839C5.73347 7.86343 5.4933 7.76389 5.31622 7.58671C5.13914 7.40953 5.03966 7.16922 5.03966 6.91865C5.03966 6.66808 5.13914 6.42778 5.31622 6.2506C5.4933 6.07342 5.73347 5.97388 5.9839 5.97388H11.0198C11.2703 5.97388 11.5104 6.07342 11.6875 6.2506C11.8646 6.42778 11.9641 6.66808 11.9641 6.91865ZM11.0198 9.12313H5.9839C5.73347 9.12313 5.4933 9.22267 5.31622 9.39985C5.13914 9.57703 5.03966 9.81734 5.03966 10.0679C5.03966 10.3185 5.13914 10.5588 5.31622 10.736C5.4933 10.9131 5.73347 11.0127 5.9839 11.0127H11.0198C11.2703 11.0127 11.5104 10.9131 11.6875 10.736C11.8646 10.5588 11.9641 10.3185 11.9641 10.0679C11.9641 9.81734 11.8646 9.57703 11.6875 9.39985C11.5104 9.22267 11.2703 9.12313 11.0198 9.12313ZM17 8.49328C17.0003 9.94978 16.6267 11.3819 15.915 12.6525C15.2032 13.923 14.1773 14.9893 12.9354 15.7492C11.6935 16.5091 10.2774 16.937 8.82277 16.992C7.36814 17.047 5.92377 16.7272 4.62813 16.0633L2.07633 16.9175C1.79854 17.0112 1.50011 17.0254 1.2147 16.9585C0.929283 16.8916 0.66822 16.7462 0.460935 16.5388C0.253649 16.3314 0.10838 16.0702 0.041502 15.7846C-0.0253764 15.499 -0.011206 15.2004 0.0824161 14.9225L0.933016 12.3692C0.348919 11.2244 0.0318046 9.96207 0.00551506 8.677C-0.0207745 7.39194 0.244445 6.11763 0.781234 4.94989C1.31802 3.78216 2.11241 2.75138 3.10467 1.93506C4.09693 1.11873 5.26124 0.538117 6.51005 0.236856C7.75887 -0.064404 9.05969 -0.0784666 10.3147 0.195726C11.5698 0.469918 12.7463 1.02523 13.756 1.81991C14.7656 2.61459 15.5821 3.62795 16.144 4.78381C16.7059 5.93967 16.9985 7.20795 17 8.49328ZM15.1115 8.49328C15.1111 7.47886 14.8775 6.47813 14.4288 5.56849C13.98 4.65886 13.3281 3.86471 12.5236 3.24748C11.719 2.63025 10.7833 2.20648 9.78886 2.00895C8.79443 1.81143 7.76791 1.84545 6.78871 2.10838C5.80952 2.3713 4.9039 2.85609 4.14191 3.52523C3.37992 4.19438 2.78199 5.02995 2.39437 5.9673C2.00674 6.90465 1.83983 7.91866 1.90652 8.93088C1.97322 9.9431 2.27174 10.9264 2.779 11.8047C2.84604 11.9205 2.88773 12.0493 2.90129 12.1824C2.91486 12.3156 2.9 12.4501 2.85769 12.5771L2.07633 14.9225L4.4204 14.1407C4.51683 14.1085 4.61777 14.0921 4.71941 14.0919C4.88524 14.0922 5.04808 14.1362 5.19153 14.2194C6.19637 14.8012 7.33663 15.1079 8.49757 15.1086C9.65851 15.1094 10.7992 14.8042 11.8048 14.2237C12.8104 13.6432 13.6454 12.808 14.2259 11.802C14.8064 10.7961 15.1119 9.65488 15.1115 8.49328Z" fill="#707070"/>'
    '</svg>';

const _kSvgNavChatFill =
    '<svg width="17" height="17" viewBox="0 0 17 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8.5 0C6.24642 0.00247486 4.08585 0.898803 2.49233 2.49233C0.898803 4.08585 0.00247486 6.24642 0 8.5V15.64C0 16.0007 0.143285 16.3466 0.398335 16.6017C0.653384 16.8567 0.999306 17 1.36 17H8.5C10.7543 17 12.9163 16.1045 14.5104 14.5104C16.1045 12.9163 17 10.7543 17 8.5C17 6.24566 16.1045 4.08365 14.5104 2.48959C12.9163 0.895533 10.7543 0 8.5 0ZM11.22 10.88H5.44C5.25965 10.88 5.08669 10.8084 4.95917 10.6808C4.83164 10.5533 4.76 10.3803 4.76 10.2C4.76 10.0197 4.83164 9.84669 4.95917 9.71917C5.08669 9.59164 5.25965 9.52 5.44 9.52H11.22C11.4003 9.52 11.5733 9.59164 11.7008 9.71917C11.8284 9.84669 11.9 10.0197 11.9 10.2C11.9 10.3803 11.8284 10.5533 11.7008 10.6808C11.5733 10.8084 11.4003 10.88 11.22 10.88ZM11.22 8.16H5.44C5.25965 8.16 5.08669 8.08836 4.95917 7.96083C4.83164 7.83331 4.76 7.66035 4.76 7.48C4.76 7.29965 4.83164 7.12669 4.95917 6.99917C5.08669 6.87164 5.25965 6.8 5.44 6.8H11.22C11.4003 6.8 11.5733 6.87164 11.7008 6.99917C11.8284 7.12669 11.9 7.29965 11.9 7.48C11.9 7.66035 11.8284 7.83331 11.7008 7.96083C11.5733 8.08836 11.4003 8.16 11.22 8.16Z" fill="#5B4A9E"/>'
    '</svg>';

const _kSvgNavUserOutline =
    '<svg width="17" height="16" viewBox="0 0 17 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15.9251 14.1038C14.9075 12.3179 13.3186 10.9263 11.4141 10.1531C12.3612 9.4428 13.0608 8.45249 13.4138 7.32248C13.7668 6.19246 13.7553 4.98002 13.3809 3.8569C13.0065 2.73379 12.2883 1.75693 11.3279 1.06471C10.3674 0.372492 9.21359 0 8.02972 0C6.84585 0 5.69199 0.372492 4.73159 1.06471C3.77118 1.75693 3.05292 2.73379 2.67855 3.8569C2.30418 4.98002 2.29267 6.19246 2.64567 7.32248C2.99866 8.45249 3.69825 9.4428 4.64534 10.1531C2.74083 10.9263 1.1519 12.3179 0.134328 14.1038C0.0712758 14.2052 0.0292516 14.3182 0.0107541 14.4362C-0.00774351 14.5541 -0.00233692 14.6746 0.0266525 14.7904C0.0556419 14.9062 0.107622 15.015 0.179503 15.1103C0.251385 15.2057 0.341699 15.2856 0.445078 15.3453C0.548456 15.405 0.662789 15.4434 0.781278 15.458C0.899767 15.4727 1.01999 15.4634 1.13481 15.4306C1.24963 15.3979 1.35669 15.3424 1.44964 15.2675C1.54258 15.1925 1.61951 15.0997 1.67585 14.9944C3.0207 12.6699 5.3957 11.2835 8.02972 11.2835C10.6637 11.2835 13.0387 12.6706 14.3836 14.9944C14.5057 15.1907 14.6993 15.3319 14.9236 15.388C15.1479 15.4442 15.3852 15.4109 15.5854 15.2952C15.7856 15.1796 15.933 14.9906 15.9964 14.7683C16.0598 14.5459 16.0342 14.3076 15.9251 14.1038ZM4.17034 5.64285C4.17034 4.87954 4.39669 4.13337 4.82077 3.4987C5.24484 2.86403 5.84759 2.36936 6.5528 2.07725C7.25801 1.78515 8.034 1.70872 8.78265 1.85763C9.53129 2.00655 10.219 2.37412 10.7587 2.91386C11.2985 3.4536 11.666 4.14128 11.8149 4.88992C11.9639 5.63857 11.8874 6.41456 11.5953 7.11977C11.3032 7.82498 10.8085 8.42773 10.1739 8.8518C9.5392 9.27588 8.79303 9.50223 8.02972 9.50223C7.00651 9.50105 6.02555 9.09406 5.30203 8.37054C4.57851 7.64702 4.17152 6.66606 4.17034 5.64285Z" fill="#707070"/>'
    '</svg>';

const _kSvgNavUserFill =
    '<svg width="17" height="16" viewBox="0 0 17 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15.9478 15.1508C15.8937 15.2449 15.8158 15.3229 15.722 15.3772C15.6283 15.4315 15.5219 15.46 15.4137 15.46H0.61594C0.507763 15.4599 0.401518 15.4312 0.307876 15.3769C0.214233 15.3226 0.136488 15.2445 0.082447 15.1506C0.0284063 15.0566 -2.77521e-05 14.95 2.03251e-08 14.8415C2.77927e-05 14.733 0.0285164 14.6265 0.0826052 14.5325C1.2564 12.4975 3.06527 11.0383 5.17626 10.3465C4.13207 9.72316 3.3208 8.77328 2.86704 7.64278C2.41327 6.51228 2.3421 5.26366 2.66446 4.08867C2.98681 2.91368 3.68487 1.87729 4.65142 1.13866C5.61798 0.400032 6.7996 0 8.01481 0C9.23002 0 10.4116 0.400032 11.3782 1.13866C12.3447 1.87729 13.0428 2.91368 13.3652 4.08867C13.6875 5.26366 13.6163 6.51228 13.1626 7.64278C12.7088 8.77328 11.8975 9.72316 10.8534 10.3465C12.9643 11.0383 14.7732 12.4975 15.947 14.5325C16.0012 14.6265 16.0299 14.733 16.03 14.8416C16.0301 14.9501 16.0018 15.0568 15.9478 15.1508Z" fill="#5B4A9E"/>'
    '</svg>';

const _kSvgNavCalendarOutline =
    '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16.2 1.33333H14.4V1C14.4 0.734784 14.2862 0.48043 14.0837 0.292893C13.8811 0.105357 13.6064 0 13.32 0C13.0336 0 12.7589 0.105357 12.5563 0.292893C12.3538 0.48043 12.24 0.734784 12.24 1V1.33333H5.76V1C5.76 0.734784 5.64621 0.48043 5.44368 0.292893C5.24114 0.105357 4.96643 0 4.68 0C4.39357 0 4.11886 0.105357 3.91632 0.292893C3.71379 0.48043 3.6 0.734784 3.6 1V1.33333H1.8C1.32261 1.33333 0.864773 1.50893 0.527208 1.82149C0.189642 2.13405 0 2.55797 0 3V16.3333C0 16.7754 0.189642 17.1993 0.527208 17.5118C0.864773 17.8244 1.32261 18 1.8 18H16.2C16.6774 18 17.1352 17.8244 17.4728 17.5118C17.8104 17.1993 18 16.7754 18 16.3333V3C18 2.55797 17.8104 2.13405 17.4728 1.82149C17.1352 1.50893 16.6774 1.33333 16.2 1.33333ZM3.6 3.33333C3.6 3.59855 3.71379 3.8529 3.91632 4.04044C4.11886 4.22798 4.39357 4.33333 4.68 4.33333C4.96643 4.33333 5.24114 4.22798 5.44368 4.04044C5.64621 3.8529 5.76 3.59855 5.76 3.33333H12.24C12.24 3.59855 12.3538 3.8529 12.5563 4.04044C12.7589 4.22798 13.0336 4.33333 13.32 4.33333C13.6064 4.33333 13.8811 4.22798 14.0837 4.04044C14.2862 3.8529 14.4 3.59855 14.4 3.33333H15.84V5.33333H2.16V3.33333H3.6ZM2.16 16V7.33333H15.84V16H2.16ZM10.44 9.66667C10.44 9.93038 10.3555 10.1882 10.1973 10.4074C10.0391 10.6267 9.81419 10.7976 9.55106 10.8985C9.28794 10.9994 8.9984 11.0258 8.71907 10.9744C8.43974 10.9229 8.18315 10.7959 7.98177 10.6095C7.78038 10.423 7.64323 10.1854 7.58767 9.92679C7.53211 9.66815 7.56062 9.40006 7.66961 9.15642C7.7786 8.91279 7.96317 8.70455 8.19998 8.55804C8.43679 8.41153 8.71519 8.33333 9 8.33333C9.38191 8.33333 9.74818 8.47381 10.0182 8.72386C10.2883 8.97391 10.44 9.31305 10.44 9.66667ZM14.76 9.66667C14.76 9.93038 14.6755 10.1882 14.5173 10.4074C14.3591 10.6267 14.1342 10.7976 13.8711 10.8985C13.6079 10.9994 13.3184 11.0258 13.0391 10.9744C12.7597 10.9229 12.5032 10.7959 12.3018 10.6095C12.1004 10.423 11.9632 10.1854 11.9077 9.92679C11.8521 9.66815 11.8806 9.40006 11.9896 9.15642C12.0986 8.91279 12.2832 8.70455 12.52 8.55804C12.7568 8.41153 13.0352 8.33333 13.32 8.33333C13.7019 8.33333 14.0682 8.47381 14.3382 8.72386C14.6083 8.97391 14.76 9.31305 14.76 9.66667ZM6.12 13.6667C6.12 13.9304 6.03555 14.1882 5.87732 14.4074C5.71909 14.6267 5.49419 14.7976 5.23106 14.8985C4.96794 14.9994 4.6784 15.0258 4.39907 14.9744C4.11974 14.9229 3.86315 14.7959 3.66177 14.6095C3.46038 14.423 3.32323 14.1854 3.26767 13.9268C3.21211 13.6681 3.24062 13.4001 3.34961 13.1564C3.4586 12.9128 3.64317 12.7045 3.87998 12.558C4.11679 12.4115 4.3952 12.3333 4.68 12.3333C5.06191 12.3333 5.42818 12.4738 5.69823 12.7239C5.96829 12.9739 6.12 13.313 6.12 13.6667ZM10.44 13.6667C10.44 13.9304 10.3555 14.1882 10.1973 14.4074C10.0391 14.6267 9.81419 14.7976 9.55106 14.8985C9.28794 14.9994 8.9984 15.0258 8.71907 14.9744C8.43974 14.9229 8.18315 14.7959 7.98177 14.6095C7.78038 14.423 7.64323 14.1854 7.58767 13.9268C7.53211 13.6681 7.56062 13.4001 7.66961 13.1564C7.7786 12.9128 7.96317 12.7045 8.19998 12.558C8.43679 12.4115 8.71519 12.3333 9 12.3333C9.38191 12.3333 9.74818 12.4738 10.0182 12.7239C10.2883 12.9739 10.44 13.313 10.44 13.6667ZM14.76 13.6667C14.76 13.9304 14.6755 14.1882 14.5173 14.4074C14.3591 14.6267 14.1342 14.7976 13.8711 14.8985C13.6079 14.9994 13.3184 15.0258 13.0391 14.9744C12.7597 14.9229 12.5032 14.7959 12.3018 14.6095C12.1004 14.423 11.9632 14.1854 11.9077 13.9268C11.8521 13.6681 11.8806 13.4001 11.9896 13.1564C12.0986 12.9128 12.2832 12.7045 12.52 12.558C12.7568 12.4115 13.0352 12.3333 13.32 12.3333C13.7019 12.3333 14.0682 12.4738 14.3382 12.7239C14.6083 12.9739 14.76 13.313 14.76 13.6667Z" fill="#707070"/>'
    '</svg>';

const _kSvgNavCalendarFill =
    '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16.5 1.38462H14.25V0.692308C14.25 0.508696 14.171 0.332605 14.0303 0.202772C13.8897 0.0729393 13.6989 0 13.5 0C13.3011 0 13.1103 0.0729393 12.9697 0.202772C12.829 0.332605 12.75 0.508696 12.75 0.692308V1.38462H5.25V0.692308C5.25 0.508696 5.17098 0.332605 5.03033 0.202772C4.88968 0.0729393 4.69891 0 4.5 0C4.30109 0 4.11032 0.0729393 3.96967 0.202772C3.82902 0.332605 3.75 0.508696 3.75 0.692308V1.38462H1.5C1.10218 1.38462 0.720644 1.53049 0.43934 1.79016C0.158035 2.04983 0 2.40201 0 2.76923V16.6154C0 16.9826 0.158035 17.3348 0.43934 17.5945C0.720644 17.8541 1.10218 18 1.5 18H16.5C16.8978 18 17.2794 17.8541 17.5607 17.5945C17.842 17.3348 18 16.9826 18 16.6154V2.76923C18 2.40201 17.842 2.04983 17.5607 1.79016C17.2794 1.53049 16.8978 1.38462 16.5 1.38462ZM4.875 14.5385C4.6525 14.5385 4.43499 14.4776 4.24998 14.3634C4.06498 14.2493 3.92078 14.0872 3.83564 13.8974C3.75049 13.7076 3.72821 13.4988 3.77162 13.2974C3.81502 13.096 3.92217 12.9109 4.0795 12.7657C4.23684 12.6205 4.43729 12.5216 4.65552 12.4815C4.87375 12.4414 5.09995 12.462 5.30552 12.5406C5.51109 12.6192 5.68679 12.7523 5.8104 12.9231C5.93402 13.0938 6 13.2946 6 13.5C6 13.7754 5.88147 14.0396 5.6705 14.2343C5.45952 14.4291 5.17337 14.5385 4.875 14.5385ZM9 14.5385C8.7775 14.5385 8.55999 14.4776 8.37498 14.3634C8.18998 14.2493 8.04578 14.0872 7.96064 13.8974C7.87549 13.7076 7.85321 13.4988 7.89662 13.2974C7.94002 13.096 8.04717 12.9109 8.2045 12.7657C8.36184 12.6205 8.56229 12.5216 8.78052 12.4815C8.99875 12.4414 9.22495 12.462 9.43052 12.5406C9.63609 12.6192 9.81179 12.7523 9.9354 12.9231C10.059 13.0938 10.125 13.2946 10.125 13.5C10.125 13.7754 10.0065 14.0396 9.79549 14.2343C9.58452 14.4291 9.29837 14.5385 9 14.5385ZM9 11.0769C8.7775 11.0769 8.55999 11.016 8.37498 10.9019C8.18998 10.7878 8.04578 10.6256 7.96064 10.4359C7.87549 10.2461 7.85321 10.0373 7.89662 9.83587C7.94002 9.63443 8.04717 9.44939 8.2045 9.30416C8.36184 9.15893 8.56229 9.06002 8.78052 9.01995C8.99875 8.97988 9.22495 9.00045 9.43052 9.07905C9.63609 9.15765 9.81179 9.29075 9.9354 9.46152C10.059 9.6323 10.125 9.83307 10.125 10.0385C10.125 10.3139 10.0065 10.578 9.79549 10.7728C9.58452 10.9675 9.29837 11.0769 9 11.0769ZM13.125 14.5385C12.9025 14.5385 12.685 14.4776 12.5 14.3634C12.315 14.2493 12.1708 14.0872 12.0856 13.8974C12.0005 13.7076 11.9782 13.4988 12.0216 13.2974C12.065 13.096 12.1722 12.9109 12.3295 12.7657C12.4868 12.6205 12.6873 12.5216 12.9055 12.4815C13.1238 12.4414 13.35 12.462 13.5555 12.5406C13.7611 12.6192 13.9368 12.7523 14.0604 12.9231C14.184 13.0938 14.25 13.2946 14.25 13.5C14.25 13.7754 14.1315 14.0396 13.9205 14.2343C13.7095 14.4291 13.4234 14.5385 13.125 14.5385ZM13.125 11.0769C12.9025 11.0769 12.685 11.016 12.5 10.9019C12.315 10.7878 12.1708 10.6256 12.0856 10.4359C12.0005 10.2461 11.9782 10.0373 12.0216 9.83587C12.065 9.63443 12.1722 9.44939 12.3295 9.30416C12.4868 9.15893 12.6873 9.06002 12.9055 9.01995C13.1238 8.97988 13.35 9.00045 13.5555 9.07905C13.7611 9.15765 13.9368 9.29075 14.0604 9.46152C14.184 9.6323 14.25 9.83307 14.25 10.0385C14.25 10.3139 14.1315 10.578 13.9205 10.7728C13.7095 10.9675 13.4234 11.0769 13.125 11.0769ZM16.5 5.53846H1.5V2.76923H3.75V3.46154C3.75 3.64515 3.82902 3.82124 3.96967 3.95107C4.11032 4.08091 4.30109 4.15385 4.5 4.15385C4.69891 4.15385 4.88968 4.08091 5.03033 3.95107C5.17098 3.82124 5.25 3.64515 5.25 3.46154V2.76923H12.75V3.46154C12.75 3.64515 12.829 3.82124 12.9697 3.95107C13.1103 4.08091 13.3011 4.15385 13.5 4.15385C13.6989 4.15385 13.8897 4.08091 14.0303 3.95107C14.171 3.82124 14.25 3.64515 14.25 3.46154V2.76923H16.5V5.53846Z" fill="#5B4A9E"/>'
    '</svg>';

class HomeDocentePage extends StatefulWidget {
  const HomeDocentePage({super.key});

  @override
  State<HomeDocentePage> createState() => _HomeDocentePageState();
}

class _HomeDocentePageState extends State<HomeDocentePage>
    with WidgetsBindingObserver {
  int _navIndex = 0;
  late Future<TeacherHomeData> _homeDataFuture;
  // Mismo problema que _lastPendingCount/_lastConnected, en el
  // FutureBuilder más grande: sin esto, reasignar _homeDataFuture (mismo
  // sync automático al abrir el home) hacía que TODO el contenido de la
  // pantalla (saludo, salón, horario, pendientes) se reseteara a sus
  // valores por defecto un instante y volviera a aparecer apenas
  // resolvía — la pantalla entera "parpadeaba" en cada apertura.
  TeacherHomeData? _lastHomeData;
  late Future<bool> _classroomStatusFuture;
  late Future<int> _pendingFuture;
  // Último valor bueno conocido de _pendingFuture: cuando el Future se
  // reasigna (sync automático, pull-to-refresh), FutureBuilder vuelve a
  // `waiting` con `data == null` de inmediato — sin esto, la card de
  // "pendientes" se ocultaba un instante (count caía a 0) y volvía a
  // aparecer con el mismo número apenas resolvía, un parpadeo visible
  // aunque el dato final no hubiera cambiado.
  int? _lastPendingCount;
  // Mismo problema que _lastPendingCount, pero acá el impacto es mayor:
  // este FutureBuilder es el que decide si se muestra TODA la sección de
  // horario + pendientes + accesos — al reasignar _classroomStatusFuture
  // (mismo sync automático), volvía a `waiting` y ocultaba todo ese
  // bloque de golpe hasta que resolvía, así que en la práctica se veía
  // como que la pantalla entera "parpadeaba" al abrir el home.
  bool? _lastConnected;
  List<ScheduleSlot>? _lastSchedule; // mismo patrón, ver _lastPendingCount
  late Future<List<ScheduleSlot>> _scheduleFuture;
  bool _waitingClassroomConfirm = false;
  // Guard de reentrada (equivale a Mejora D del padre): evita syncs a Google
  // concurrentes entre post-frame, pull-to-refresh y resume.
  bool _refreshing = false;

  // Prueba: las cards de "Accesos Rápidos" y "pendientes" del home del
  // docente todavía no tienen destino propio (a diferencia del home del
  // padre) — mientras se define uno real para cada una, todas llevan a
  // Chats para poder validar el feedback de toque (PressTint) en algo
  // que sí navega.
  void _goToChats() => setState(() => _navIndex = 1);

  @override
  void initState() {
    super.initState();
    // Pedido de "abrir en la pestaña Chats" (ver main.dart, al tocar una
    // notificación de mensaje) — se consume acá si este Home se está
    // montando recién ahora; si ya estaba vivo, lo agarra el listener de
    // abajo en cambio. Ver InboxSyncService.requestChatsTab.
    final pendingTab = InboxSyncService.instance.consumeChatsTabRequest();
    if (pendingTab != null) _navIndex = pendingTab;
    InboxSyncService.instance.chatsTabRequests.addListener(_onChatsTabRequested);
    WidgetsBinding.instance.addObserver(this);
    final repo = TeacherRepository(context.read<ApiClient>());
    _homeDataFuture = repo.getHomeData();
    // Fuente única de `connected` (Mejora A del padre): se deriva de getHomeData,
    // eliminando el GET /classroom/teacher/status redundante.
    _classroomStatusFuture = _homeDataFuture.then((d) => d.connected);
    _pendingFuture = repo.getPendingCount();
    _scheduleFuture = repo.getTodaySchedule();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _syncOnLogin();
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        await maybeShowNotificationOnboarding(context, authState.user);
        await maybeShowAutostartReminder(context);
      }
    });
  }

  Future<void> _syncOnLogin() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final repo = TeacherRepository(context.read<ApiClient>());
      // Espera el primer getHomeData (ya lanzado en initState) para conocer
      // `connected` sin un request extra a /status.
      final home = await _homeDataFuture;
      if (!mounted) return;
      // Sync solo si el docente está conectado (evita 403 y llamadas a Google).
      var cacheHit = false;
      if (home.connected) {
        try {
          final result = await repo.syncClassroom();
          cacheHit = result.cacheHit;
        } catch (_) {}
      }
      if (!mounted) return;
      // Solo re-pedir todo (incluido getHomeData) si el docente está
      // conectado Y el sync trajo algo nuevo. Antes esta condición solo
      // protegía a _pendingFuture/_scheduleFuture — getHomeData se volvía
      // a pedir SIEMPRE (línea suelta afuera del if), duplicando la
      // request de initState en cada apertura del home, incluso sin
      // Classroom conectado o con cache hit (nada nuevo que mostrar).
      if (home.connected && !cacheHit) {
        setState(() {
          _homeDataFuture = repo.getHomeData();
          _classroomStatusFuture = _homeDataFuture.then((d) => d.connected);
          _pendingFuture = repo.getPendingCount();
          _scheduleFuture = repo.getTodaySchedule();
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  void _onAttendanceComplete() {
    if (!mounted) return;
    final repo = TeacherRepository(context.read<ApiClient>());
    setState(() => _homeDataFuture = repo.getHomeData());
  }

  void _onChatsTabRequested() {
    final pendingTab = InboxSyncService.instance.consumeChatsTabRequest();
    if (pendingTab != null && mounted) setState(() => _navIndex = pendingTab);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    InboxSyncService.instance.chatsTabRequests.removeListener(_onChatsTabRequested);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingClassroomConfirm) {
      _verifyClassroomConnection();
    }
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final repo = TeacherRepository(context.read<ApiClient>());
      // Sync solo si el docente está conectado (evita 403 y llamadas a Google).
      final home = await _homeDataFuture;
      var cacheHit = false;
      if (home.connected) {
        try {
          final result = await repo.syncClassroom();
          cacheHit = result.cacheHit;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _homeDataFuture = repo.getHomeData();
        _classroomStatusFuture = _homeDataFuture.then((d) => d.connected);
        // Solo re-lanzar pending/schedule si el docente está conectado
        // Y no hubo cache hit (evita duplicados cuando no está conectado).
        if (home.connected && !cacheHit) {
                _pendingFuture = repo.getPendingCount();
          _scheduleFuture = repo.getTodaySchedule();
        }
        _waitingClassroomConfirm = false;
      });
      await Future.wait([_homeDataFuture, _classroomStatusFuture]);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _connectClassroom() async {
    try {
      final repo = TeacherRepository(context.read<ApiClient>());
      final url = await repo.getClassroomAuthUrl();
      // inAppBrowserView (Custom Tabs en Android) en vez de externalApplication:
      // este último abre el navegador como una app aparte, y Android puede
      // matar el proceso de Kolexa mientras está en segundo plano — al volver
      // del consentimiento de Google, la app arrancaba en frío de nuevo
      // (splash otra vez) aunque el celular fuera gama alta. Custom Tabs corre
      // dentro de la misma tarea, así que ya no se ve como "otra app".
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el navegador')),
        );
        return;
      }
      if (mounted) setState(() => _waitingClassroomConfirm = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  Future<void> _verifyClassroomConnection() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final repo = TeacherRepository(context.read<ApiClient>());
      if (mounted) {
        setState(() => _waitingClassroomConfirm = false);
      }
      var cacheHit = false;
      try {
        final result = await repo.syncClassroom();
        cacheHit = result.cacheHit;
      } catch (_) {}
      if (!mounted) return;
      // Fuente única de `connected`: getHomeData (Mejora A). Sin doble /status.
      final home = await repo.getHomeData();
      if (!mounted) return;
      setState(() {
        _homeDataFuture = Future.value(home);
        _classroomStatusFuture = Future.value(home.connected);
        // Solo re-lanzar pending si el docente está conectado Y no hubo
        // cache hit (evita duplicados cuando no está conectado).
        if (home.connected && !cacheHit) {
                _pendingFuture = repo.getPendingCount();
        }
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final authState = context.read<AuthBloc>().state;
    final firstName = authState is AuthAuthenticated ? authState.user.firstName : '';
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

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
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
                onRefresh: _onRefresh,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: FutureBuilder<TeacherHomeData>(
                      future: _homeDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) _lastHomeData = snapshot.data;
                        final data = _lastHomeData;
                        final classroom = data?.classrooms.length == 1
                            ? data!.classrooms.first
                            : null;
                        final hasSchedule = data?.hasSchedule ?? false;

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                              sizes.cardPadding, 0, sizes.cardPadding, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Banner: notificaciones desactivadas ──
                              const NotificationBanner(),
                              const SizedBox(height: 12),

                              // ── Header: saludo ──────────────────
                              Text('Hola, $firstName',
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
                              const SizedBox(height: 16),

                              // ── Card principal ──────────────────
                              // Sin Classroom conectado no hay salón ni
                              // alumnos, así que "Tomar asistencia" no lleva a
                              // ningún lado. En ese caso el primer card es la
                              // conexión con Classroom: el único paso que el
                              // docente puede dar al entrar por primera vez.
                              FutureBuilder<bool>(
                                future: _classroomStatusFuture,
                                builder: (context, snap) {
                                  final connected = snap.data == true;
                                  final resolving = snap.connectionState ==
                                      ConnectionState.waiting;
                                  if (!resolving && !connected) {
                                    return _ClassroomConnectCard(
                                      waitingConfirm: _waitingClassroomConfirm,
                                      onConnect: _connectClassroom,
                                      onVerify: _verifyClassroomConnection,
                                    );
                                  }
                                  return _SalonCard(
                                    classroom: classroom,
                                    gcSection: data?.gcSection,
                                    gcStudentCount: data?.gcStudentCount,
                                    showCreateButton: data != null && !hasSchedule,
                                    isLoading: resolving ||
                                        snapshot.connectionState ==
                                            ConnectionState.waiting,
                                    repo: TeacherRepository(
                                        context.read<ApiClient>()),
                                    attendanceState:
                                        data?.attendanceState ?? 'none',
                                    attendanceSummary: data?.attendanceSummary,
                                    onAttendanceComplete: _onAttendanceComplete,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              // ── Horario del día (cuando hay horario)
                              if (hasSchedule) ...[
                                Text('Horario',
                                    style: TextStyle(
                                      fontSize: sizes.textLabelCard,
                                      fontWeight: FontWeight.w600,
                                      color: _kTextGray,
                                    )),
                                const SizedBox(height: 10),
                                FutureBuilder<List<ScheduleSlot>>(
                                  future: _scheduleFuture,
                                  builder: (ctx, sSnap) {
                                    if (sSnap.hasData) _lastSchedule = sSnap.data;
                                    return _HorarioRow(
                                      slots: _lastSchedule ?? [],
                                      now: now,
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ── Cursos y pendientes (si hay classroom)
                              FutureBuilder<bool>(
                                future: _classroomStatusFuture,
                                builder: (context, snap) {
                                  if (snap.hasData) _lastConnected = snap.data;
                                  if (_lastConnected != true) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Pendientes
                                      FutureBuilder<int>(
                                        future: _pendingFuture,
                                        builder: (context, pendSnap) {
                                          if (pendSnap.hasData) _lastPendingCount = pendSnap.data;
                                          final count = _lastPendingCount ?? 0;
                                          if (count == 0) return const SizedBox.shrink();
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _PendientesDocenteCard(
                                                pendingCount: count,
                                                onTap: _goToChats,
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),

                              // ── Aviso plan semanal (con horario guardado)
                              if (data != null && hasSchedule) ...[
                                const _AvisoBanner(),
                                const SizedBox(height: 12),
                              ],

                              // ── Accesos rápidos (siempre visible)
                              Text('Accesos Rápidos',
                                  style: TextStyle(
                                    fontSize: sizes.textLabelCard,
                                    color: _kTextGray,
                                  )),
                              const SizedBox(height: 10),
                              _AccesosRapidosDocente(onItemTap: _goToChats),
                              const SizedBox(height: 12),

                              // El card de conexión con Classroom ahora vive
                              // arriba, en lugar del card de salón, para que
                              // sea lo primero que el docente ve al entrar sin
                              // haber conectado. Ver el FutureBuilder de más
                              // arriba.
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              ),
            ),
            _BottomNavDocente(
              selected: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: mi salón (avatar + nombre + botón de acción directa)
// ─────────────────────────────────────────────────────────
class _SalonCard extends StatelessWidget {
  final TeacherClassroom? classroom;
  final String? gcSection;
  final int? gcStudentCount;
  final bool showCreateButton;
  final bool isLoading;
  final TeacherRepository repo;
  final String attendanceState; // 'none' | 'attendance_only' | 'complete'
  final AttendanceSummary? attendanceSummary;
  final VoidCallback? onAttendanceComplete;

  const _SalonCard({
    required this.classroom,
    required this.showCreateButton,
    required this.isLoading,
    required this.repo,
    this.gcSection,
    this.gcStudentCount,
    this.attendanceState = 'none',
    this.attendanceSummary,
    this.onAttendanceComplete,
  });

  void _openPhotoModal(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PhotoModal(
        onConfirm: (List<XFile> photos) async {
          try {
            if (photos.isNotEmpty) {
              await repo.uploadAttendancePhotos(
                date: date,
                photoPaths: photos.map((p) => p.path).toList(),
              );
            }
          } catch (_) {}
          if (!context.mounted) return;
          Navigator.pop(context);
          onAttendanceComplete?.call();
        },
        onSkip: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final salonName = classroom != null
        ? classroom!.name
        : (isLoading ? '...' : (gcSection ?? 'Sin salón asignado'));

    final count = classroom?.studentCount ?? gcStudentCount;
    final String subtitle;
    if (attendanceSummary != null) {
      subtitle = attendanceSummary!.label;
    } else {
      final scheduleText = showCreateButton ? 'Sin horario' : null;
      subtitle = [
        if (count != null) '$count alumnos hábiles',
        if (scheduleText != null) scheduleText,
      ].join('  ·  ');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: sizes.circleIconNovedades,
                height: sizes.circleIconNovedades,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/ic_cap.svg',
                  width: sizes.glyphNovedades,
                  height: sizes.glyphNovedades * 17 / 24,
                  colorFilter:
                      const ColorFilter.mode(_kPrimary, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(salonName,
                        style: TextStyle(
                          fontSize: sizes.textValueCard,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        )),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                            fontSize: sizes.textLabelCard,
                            color: _kTextGray,
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // El horario lo carga el colegio desde Web Admin (una vez por
          // bimestre, leyendo la foto del cuadro de horarios). El docente solo
          // lo consulta: sin un botón que prometa editarlo, la pregunta
          // "¿dónde lo cargo?" se responde antes de que aparezca.
          if (showCreateButton) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF3FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.info_outline,
                      size: 11, color: Color(0xFF476376)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tu colegio aún no ha cargado el horario.',
                    style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray),
                  ),
                ),
              ],
            ),
          ] else if (attendanceState == 'complete') ...[
            // ✓ Asistencia y foto listas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0EFE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '✓ asistencia y foto del día listas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kSuccessText,
                ),
              ),
            ),
          ] else if (attendanceState == 'attendance_only') ...[
            // Tomar foto del día
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openPhotoModal(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('tomar foto del día',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            // Tomar asistencia
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final now = DateTime.now();
                  final days = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
                  final months = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
                  final dateLabel = '${days[now.weekday]} ${now.day} de ${months[now.month]}';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendancePage(
                        classroomName: salonName,
                        dateLabel: dateLabel,
                        repo: repo,
                      ),
                    ),
                  ).then((_) => onAttendanceComplete?.call());
                },
                icon: const Icon(Icons.timer_outlined,
                    size: 16, color: Colors.white),
                label: const Text('Tomar asistencia',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Horario del día: fila con scroll horizontal
// ─────────────────────────────────────────────────────────
class _HorarioRow extends StatelessWidget {
  final List<ScheduleSlot> slots;
  final DateTime now;
  const _HorarioRow({required this.slots, required this.now});

  String _fmt(String hhmm) {
    final p = hhmm.split(':');
    final h = int.parse(p[0]);
    final m = p[1];
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m';
  }

  @override
  Widget build(BuildContext context) {
    final current = slots.firstWhere(
      (s) => s.isActive(now),
      orElse: () => const ScheduleSlot(
          courseName: 'Sin clase ahora',
          type: 'none',
          startTime: '--:--',
          endTime: '--:--'),
    );
    final upcoming = slots.where((s) => s.isUpcoming(now)).toList();
    final next = upcoming.isNotEmpty ? upcoming.first : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ClaseActualChip(slot: current, fmt: _fmt),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: _MiniClaseChip(
              nombre: next?.courseName ?? '–',
              hora: next != null ? _fmt(next.startTime) : '–',
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaseActualChip extends StatelessWidget {
  final ScheduleSlot slot;
  final String Function(String) fmt;
  const _ClaseActualChip({required this.slot, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final isActive = slot.type != 'none';
    final label = isActive
        ? '${fmt(slot.startTime)} – ${fmt(slot.endTime)} · En curso'
        : 'Sin clase ahora';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: sizes.circleIconNovedades,
            height: sizes.circleIconNovedades,
            decoration: const BoxDecoration(
              color: _kPrimaryLt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.schedule_rounded,
                size: sizes.glyphNovedades, color: _kPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(slot.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: sizes.textValueCard,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    )),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? _kSuccessText : _kTextGray,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniClaseChip extends StatelessWidget {
  final String nombre;
  final String hora;
  const _MiniClaseChip({required this.nombre, required this.hora});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF999999),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(hora,
              style: const TextStyle(fontSize: 11, color: _kTextGray)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: pendientes (tareas, reuniones, y más)
// ─────────────────────────────────────────────────────────
class _PendientesDocenteCard extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;
  const _PendientesDocenteCard({required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final label = '$pendingCount pendientes esta semana';
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: PressTint(
        onTap: onTap,
        tintColor: pressedTint(Colors.white),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
        children: [
          Container(
            width: sizes.circleIconNovedades,
            height: sizes.circleIconNovedades,
            decoration: const BoxDecoration(
              color: _kBannerBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.chat_bubble_outline, color: _kAmber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: sizes.textValueCard,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    )),
                const SizedBox(height: 2),
                Text('Tareas por calificar',
                    style: TextStyle(
                      fontSize: sizes.textLabelCard,
                      color: _kTextGray,
                    )),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: _kChevron, size: sizes.iconChevron),
        ],
        ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────
// Aviso: plan semanal
// ─────────────────────────────────────────────────────────
class _AvisoBanner extends StatelessWidget {
  const _AvisoBanner();

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kBannerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _kBannerText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Actualiza el plan semanal antes del lunes',
                style: TextStyle(
                  fontSize: sizes.textLabelCard,
                  fontWeight: FontWeight.w600,
                  color: _kBannerText,
                )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Accesos rápidos (2 filas × 3)
// ─────────────────────────────────────────────────────────
class _AccesosRapidosDocente extends StatelessWidget {
  final VoidCallback onItemTap;
  const _AccesosRapidosDocente({required this.onItemTap});

  static const _items = [
    (Icons.calendar_month_outlined, 'Plan semanal'),
    (Icons.schedule_outlined, 'Horario'),
    (Icons.assignment_outlined, 'Tareas'),
    (Icons.grade_outlined, 'Calificaciones'),
    (Icons.campaign_outlined, 'Comunicados'),
    (Icons.emoji_events_outlined, 'Logros'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: _items.take(3).map((i) => _buildItem(context, i)).toList()),
        const SizedBox(height: 10),
        Row(children: _items.skip(3).map((i) => _buildItem(context, i)).toList()),
      ],
    );
  }

  Widget _buildItem(BuildContext context, (IconData, String) item) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: PressTint(
          onTap: onItemTap,
          tintColor: pressedTint(Colors.white),
          borderRadius: BorderRadius.circular(16),
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
// Card: conectar Google Classroom del docente
// ─────────────────────────────────────────────────────────
class _ClassroomConnectCard extends StatelessWidget {
  final bool waitingConfirm;
  final VoidCallback onConnect;
  final VoidCallback onVerify;

  const _ClassroomConnectCard({
    required this.waitingConfirm,
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
        border: Border.all(color: const Color(0xFFEDE8FA), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: sizes.circleIconNovedades,
                height: sizes.circleIconNovedades,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_outlined,
                    color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conecta Google Classroom',
                        style: TextStyle(
                          fontSize: sizes.textValueCard,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        )),
                    const SizedBox(height: 2),
                    Text('Sincroniza tus cursos y alumnos',
                        style: TextStyle(
                          fontSize: sizes.textLabelCard,
                          color: _kTextGray,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link, size: 16, color: Colors.white),
              label: Text('Conectar con Google',
                  style: TextStyle(
                    fontSize: sizes.textValueCard,
                    fontWeight: FontWeight.w700,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (waitingConfirm) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                ),
                const SizedBox(width: 8),
                Text('Verificando conexión...',
                    style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom Nav (4 tabs: Inicio, Alumnos, Bandeja, Perfil)
// ─────────────────────────────────────────────────────────
class _BottomNavDocente extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _BottomNavDocente({required this.selected, required this.onTap});

  // (svg outline/inactivo, svg fill/activo, label)
  // Igual tal cual al nav del padre (mismos nombres e íconos) — pendiente de
  // ajustar a lo específico del docente en una siguiente pasada.
  static const _items = [
    (_kSvgNavHouseOutline, _kSvgNavHouseFill, 'Inicio'),
    (_kSvgNavChatOutline, _kSvgNavChatFill, 'Chats'),
    (_kSvgNavCalendarOutline, _kSvgNavCalendarFill, 'Pendientes'),
    (_kSvgNavUserOutline, _kSvgNavUserFill, 'Perfil'),
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
                  final (svgOutline, svgFill, label) = e.value;
                  final active = i == selected;
                  final color = active ? _kNavActive : _kNavInact;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
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
                                  active ? svgFill : svgOutline,
                                  width: sizes.iconBottomNav,
                                  height: sizes.iconBottomNav,
                                  colorFilter:
                                      ColorFilter.mode(color, BlendMode.srcIn),
                                ),
                              ),
                              if (label == 'Chats')
                                Positioned(
                                  top: -2,
                                  right: -10,
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: InboxSyncService.instance.unreadCount,
                                    builder: (context, count, _) {
                                      if (count <= 0) return const SizedBox.shrink();
                                      return Container(
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: const BoxDecoration(
                                          color: _kNavBadge,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            count > 9 ? '9+' : '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                fontSize: sizes.textLabelBottomNav,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: color,
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
// Tab Perfil — solo cerrar sesión (compartido con home padre)
// ─────────────────────────────────────────────────────────
class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(const LogoutEvent()),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Cerrar sesión',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBA3428),
              side: const BorderSide(color: Color(0xFFBA3428)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}
