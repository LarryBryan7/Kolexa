// ============================================================
// inbox_page.dart — "Chats": la bandeja de mensajería
// ============================================================
// Se embebe como pestaña dentro del home (igual que PerfilTab), no tiene
// Scaffold propio.
//
// Los chips "Comunicados" y "Reuniones" son del diseño de Figma, pero el
// backend solo crea hilos con kind:'direct' — no existe esa categoría en
// los datos reales todavía. Se muestran (fidelidad visual) pero no
// filtran nada real: al tocarlos se avisa que aún no está disponible, en
// vez de simular datos que no existen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../data/threads_repository.dart';
import 'new_message_page.dart';
import 'thread_page.dart';

const _kBg = Color(0xFFF7F6F3);
const _kHeaderTitle = Color(0xFF444444);
const _kTextGray = Color(0xFF666666);
const _kUnreadText = Color(0xFF111116);
// El violeta "de marca" (chip Mensajes activo) y el violeta "de chat"
// (badges de no-leído, botón de Kolexa) son medidos distintos en Figma —
// no es el mismo tono, no hay que unificarlos.
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kChipBadgeActiveBg = Color(0xFFD4C9F0);
const _kAccent = Color(0xFF9F6CF3);
const _kAccentLt = Color(0xFFEDE8FA);
const _kChipInactiveBg = Color(0xFFF0F0F0);
const _kChipBadgeInactiveBg = Color(0xFFDEDEDE);
const _kChipBadgeInactiveText = Color(0xFFA9A9A9);
const _kOfflineDot = Color(0xFFCDCFCC);
const _kOnlineDot = Color(0xFF4CAF50);

const _kSvgMagnifyingGlass =
    '<svg width="17" height="17" viewBox="0 0 17 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16.6165 15.29L12.9064 11.5783C14.0188 10.1286 14.5382 8.31013 14.3591 6.49165C14.1801 4.67318 13.316 2.99089 11.9422 1.78607C10.5684 0.581238 8.78776 -0.0559155 6.96147 0.00385482C5.13518 0.0636252 3.4 0.815844 2.10792 2.10792C0.815844 3.4 0.0636252 5.13518 0.00385482 6.96147C-0.0559155 8.78776 0.581238 10.5684 1.78607 11.9422C2.99089 13.316 4.67318 14.1801 6.49165 14.3591C8.31013 14.5382 10.1286 14.0188 11.5783 12.9064L15.2915 16.6205C15.3788 16.7077 15.4823 16.7768 15.5962 16.824C15.7102 16.8712 15.8323 16.8955 15.9556 16.8955C16.0789 16.8955 16.2011 16.8712 16.315 16.824C16.4289 16.7768 16.5325 16.7077 16.6197 16.6205C16.7069 16.5332 16.7761 16.4297 16.8232 16.3158C16.8704 16.2018 16.8947 16.0797 16.8947 15.9564C16.8947 15.8331 16.8704 15.7109 16.8232 15.597C16.7761 15.4831 16.7069 15.3795 16.6197 15.2923L16.6165 15.29ZM1.89076 7.20326C1.89076 6.15255 2.20234 5.12543 2.78608 4.2518C3.36983 3.37816 4.19952 2.69724 5.17026 2.29515C6.14099 1.89306 7.20916 1.78786 8.23968 1.99284C9.2702 2.19782 10.2168 2.70379 10.9598 3.44676C11.7027 4.18972 12.2087 5.13632 12.4137 6.16685C12.6187 7.19737 12.5135 8.26554 12.1114 9.23627C11.7093 10.207 11.0284 11.0367 10.1547 11.6204C9.28109 12.2042 8.25398 12.5158 7.20326 12.5158C5.79474 12.5143 4.44433 11.9541 3.44836 10.9582C2.45238 9.96219 1.89221 8.61178 1.89076 7.20326Z" fill="#666666"/>'
    '</svg>';

const _kSvgComposeNewMessage =
    '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M3.90789 4.08333H8.96053M3.90789 6.75H7.69737M6.44053 10.4793L3.90789 12.0833V10.0833H2.64474C2.14222 10.0833 1.66029 9.87262 1.30496 9.49755C0.949624 9.12247 0.75 8.61377 0.75 8.08333V2.75C0.75 2.21957 0.949624 1.71086 1.30496 1.33579C1.66029 0.960714 2.14222 0.75 2.64474 0.75H10.2237C10.7262 0.75 11.2081 0.960714 11.5635 1.33579C11.9188 1.71086 12.1184 2.21957 12.1184 2.75V6.41667M8.96053 10.75H12.75M10.8553 8.75V12.75" stroke="#9F6CF3" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgSingleCheck =
    '<svg width="10" height="6" viewBox="0 0 10 6" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M9.88278 0.56931L3.48307 5.90225C3.44592 5.93324 3.40181 5.95782 3.35325 5.97459C3.30469 5.99137 3.25264 6 3.20008 6C3.14752 6 3.09547 5.99137 3.04691 5.97459C2.99835 5.95782 2.95424 5.93324 2.91709 5.90225L0.117217 3.56909C0.0421643 3.50654 0 3.42172 0 3.33327C0 3.24482 0.0421643 3.16 0.117217 3.09745C0.19227 3.03491 0.294064 2.99978 0.400205 2.99978C0.506345 2.99978 0.608139 3.03491 0.683192 3.09745L3.20008 5.19521L9.31681 0.0976779C9.39186 0.0351357 9.49365 -6.58989e-10 9.5998 0C9.70594 6.5899e-10 9.80773 0.0351357 9.88278 0.0976779C9.95784 0.16022 10 0.245046 10 0.333494C10 0.421942 9.95784 0.506767 9.88278 0.56931Z" fill="#666666"/>'
    '</svg>';

// Doble check ("entregado" — ver ThreadSummary.lastMessage.delivered): el
// mismo trazo de _kSvgSingleCheck, dibujado dos veces con un offset
// horizontal, igual al patrón visual de WhatsApp.
const _kSvgDoubleCheck =
    '<svg width="14" height="6" viewBox="0 0 14 6" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M9.88278 0.56931L3.48307 5.90225C3.44592 5.93324 3.40181 5.95782 3.35325 5.97459C3.30469 5.99137 3.25264 6 3.20008 6C3.14752 6 3.09547 5.99137 3.04691 5.97459C2.99835 5.95782 2.95424 5.93324 2.91709 5.90225L0.117217 3.56909C0.0421643 3.50654 0 3.42172 0 3.33327C0 3.24482 0.0421643 3.16 0.117217 3.09745C0.19227 3.03491 0.294064 2.99978 0.400205 2.99978C0.506345 2.99978 0.608139 3.03491 0.683192 3.09745L3.20008 5.19521L9.31681 0.0976779C9.39186 0.0351357 9.49365 -6.58989e-10 9.5998 0C9.70594 6.5899e-10 9.80773 0.0351357 9.88278 0.0976779C9.95784 0.16022 10 0.245046 10 0.333494C10 0.421942 9.95784 0.506767 9.88278 0.56931Z" fill="#666666"/>'
    '<path d="M9.88278 0.56931L3.48307 5.90225C3.44592 5.93324 3.40181 5.95782 3.35325 5.97459C3.30469 5.99137 3.25264 6 3.20008 6C3.14752 6 3.09547 5.99137 3.04691 5.97459C2.99835 5.95782 2.95424 5.93324 2.91709 5.90225L0.117217 3.56909C0.0421643 3.50654 0 3.42172 0 3.33327C0 3.24482 0.0421643 3.16 0.117217 3.09745C0.19227 3.03491 0.294064 2.99978 0.400205 2.99978C0.506345 2.99978 0.608139 3.03491 0.683192 3.09745L3.20008 5.19521L9.31681 0.0976779C9.39186 0.0351357 9.49365 -6.58989e-10 9.5998 0C9.70594 6.5899e-10 9.80773 0.0351357 9.88278 0.0976779C9.95784 0.16022 10 0.245046 10 0.333494C10 0.421942 9.95784 0.506767 9.88278 0.56931Z" fill="#666666" transform="translate(4,0)"/>'
    '</svg>';

const _kSvgKolexaButton =
    '<svg width="181" height="40" viewBox="0 0 181 40" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="181" height="40" rx="20" fill="#9F6CF3"/>'
    '<path d="M47.0537 24V16H50.21C50.8167 16 51.3337 16.1159 51.7607 16.3477C52.1878 16.5768 52.5133 16.8958 52.7373 17.3047C52.9639 17.7109 53.0771 18.1797 53.0771 18.7109C53.0771 19.2422 52.9626 19.7109 52.7334 20.1172C52.5042 20.5234 52.1722 20.8398 51.7373 21.0664C51.305 21.293 50.7816 21.4062 50.167 21.4062H48.1553V20.0508H49.8936C50.2191 20.0508 50.4873 19.9948 50.6982 19.8828C50.9118 19.7682 51.0706 19.6107 51.1748 19.4102C51.2816 19.207 51.335 18.974 51.335 18.7109C51.335 18.4453 51.2816 18.2135 51.1748 18.0156C51.0706 17.8151 50.9118 17.6602 50.6982 17.5508C50.4847 17.4388 50.2139 17.3828 49.8857 17.3828H48.7451V24H47.0537ZM54.1445 24V18H55.7578V19.0469H55.8203C55.9297 18.6745 56.1133 18.3932 56.3711 18.2031C56.6289 18.0104 56.9258 17.9141 57.2617 17.9141C57.3451 17.9141 57.4349 17.9193 57.5313 17.9297C57.6276 17.9401 57.7122 17.9544 57.7852 17.9727V19.4492C57.707 19.4258 57.599 19.4049 57.4609 19.3867C57.3229 19.3685 57.1966 19.3594 57.082 19.3594C56.8372 19.3594 56.6185 19.4128 56.4258 19.5195C56.2357 19.6237 56.0846 19.7695 55.9727 19.957C55.8633 20.1445 55.8086 20.3607 55.8086 20.6055V24H54.1445ZM61.1006 24.1172C60.4834 24.1172 59.9521 23.9922 59.5068 23.7422C59.0641 23.4896 58.723 23.1328 58.4834 22.6719C58.2438 22.2083 58.124 21.6602 58.124 21.0273C58.124 20.4102 58.2438 19.8685 58.4834 19.4023C58.723 18.9362 59.0602 18.5729 59.4951 18.3125C59.9326 18.0521 60.4456 17.9219 61.0342 17.9219C61.43 17.9219 61.7985 17.9857 62.1396 18.1133C62.4834 18.2383 62.7829 18.4271 63.0381 18.6797C63.2959 18.9323 63.4964 19.25 63.6396 19.6328C63.7829 20.013 63.8545 20.4583 63.8545 20.9687V21.4258H58.7881V20.3945H62.2881C62.2881 20.1549 62.236 19.9427 62.1318 19.7578C62.0277 19.5729 61.8831 19.4284 61.6982 19.3242C61.516 19.2174 61.3037 19.1641 61.0615 19.1641C60.8089 19.1641 60.585 19.2227 60.3896 19.3398C60.1969 19.4544 60.0459 19.6094 59.9365 19.8047C59.8271 19.9974 59.7712 20.2122 59.7686 20.4492V21.4297C59.7686 21.7266 59.8232 21.9831 59.9326 22.1992C60.0446 22.4154 60.2021 22.582 60.4053 22.6992C60.6084 22.8164 60.8493 22.875 61.1279 22.875C61.3128 22.875 61.4821 22.849 61.6357 22.7969C61.7894 22.7448 61.9209 22.6667 62.0303 22.5625C62.1396 22.4583 62.223 22.3307 62.2803 22.1797L63.8193 22.2812C63.7412 22.651 63.5811 22.974 63.3389 23.25C63.0993 23.5234 62.7894 23.737 62.4092 23.8906C62.0316 24.0417 61.5954 24.1172 61.1006 24.1172ZM67.6436 26.375C67.1045 26.375 66.6423 26.3008 66.2568 26.1523C65.874 26.0065 65.5693 25.8073 65.3428 25.5547C65.1162 25.3021 64.9691 25.0182 64.9014 24.7031L66.4404 24.4961C66.4873 24.6159 66.5615 24.7279 66.6631 24.832C66.7646 24.9362 66.8988 25.0195 67.0654 25.082C67.2347 25.1471 67.4404 25.1797 67.6826 25.1797C68.0446 25.1797 68.3428 25.0911 68.5771 24.9141C68.8141 24.7396 68.9326 24.4466 68.9326 24.0352V22.9375H68.8623C68.7894 23.1042 68.68 23.2617 68.5342 23.4102C68.3883 23.5586 68.2008 23.6797 67.9717 23.7734C67.7425 23.8672 67.4691 23.9141 67.1514 23.9141C66.7008 23.9141 66.2907 23.8099 65.9209 23.6016C65.5537 23.3906 65.2607 23.069 65.042 22.6367C64.8258 22.2018 64.7178 21.6523 64.7178 20.9883C64.7178 20.3086 64.8285 19.7409 65.0498 19.2852C65.2712 18.8294 65.5654 18.4883 65.9326 18.2617C66.3024 18.0352 66.7074 17.9219 67.1475 17.9219C67.4834 17.9219 67.7646 17.9792 67.9912 18.0938C68.2178 18.2057 68.4001 18.3464 68.5381 18.5156C68.6787 18.6823 68.7868 18.8464 68.8623 19.0078H68.9248V18H70.5771V24.0586C70.5771 24.569 70.4521 24.9961 70.2021 25.3398C69.9521 25.6836 69.6058 25.9414 69.1631 26.1133C68.723 26.2878 68.2165 26.375 67.6436 26.375ZM67.6787 22.6641C67.9469 22.6641 68.1735 22.5977 68.3584 22.4648C68.5459 22.3294 68.6891 22.1367 68.7881 21.8867C68.8896 21.6341 68.9404 21.332 68.9404 20.9805C68.9404 20.6289 68.891 20.3242 68.792 20.0664C68.693 19.806 68.5498 19.6042 68.3623 19.4609C68.1748 19.3177 67.9469 19.2461 67.6787 19.2461C67.4053 19.2461 67.1748 19.3203 66.9873 19.4687C66.7998 19.6146 66.6579 19.8177 66.5615 20.0781C66.4652 20.3385 66.417 20.6393 66.417 20.9805C66.417 21.3268 66.4652 21.6263 66.5615 21.8789C66.6605 22.1289 66.8024 22.3229 66.9873 22.4609C67.1748 22.5964 67.4053 22.6641 67.6787 22.6641ZM75.749 21.4453V18H77.4131V24H75.8154V22.9102H75.7529C75.6175 23.2617 75.3923 23.5443 75.0771 23.7578C74.7646 23.9714 74.3831 24.0781 73.9326 24.0781C73.5316 24.0781 73.1787 23.987 72.874 23.8047C72.5693 23.6224 72.3311 23.3633 72.1592 23.0273C71.9899 22.6914 71.904 22.2891 71.9014 21.8203V18H73.5654V21.5234C73.568 21.8776 73.6631 22.1576 73.8506 22.3633C74.0381 22.569 74.2894 22.6719 74.6045 22.6719C74.805 22.6719 74.9925 22.6263 75.167 22.5352C75.3415 22.4414 75.4821 22.3034 75.5889 22.1211C75.6982 21.9388 75.7516 21.7135 75.749 21.4453ZM80.4082 20.5313V24H78.7441V18H80.3301V19.0586H80.4004C80.5332 18.7096 80.7559 18.4336 81.0684 18.2305C81.3809 18.0247 81.7598 17.9219 82.2051 17.9219C82.6217 17.9219 82.985 18.013 83.2949 18.1953C83.6048 18.3776 83.8457 18.638 84.0176 18.9766C84.1895 19.3125 84.2754 19.7135 84.2754 20.1797V24H82.6113V20.4766C82.6139 20.1094 82.5202 19.8229 82.3301 19.6172C82.14 19.4089 81.8783 19.3047 81.5449 19.3047C81.321 19.3047 81.123 19.3529 80.9512 19.4492C80.7819 19.5456 80.6491 19.6862 80.5527 19.8711C80.459 20.0534 80.4108 20.2734 80.4082 20.5313ZM88.7783 18V19.25H85.165V18H88.7783ZM85.9854 16.5625H87.6494V22.1562C87.6494 22.3099 87.6729 22.4297 87.7197 22.5156C87.7666 22.599 87.8317 22.6576 87.915 22.6914C88.001 22.7253 88.0999 22.7422 88.2119 22.7422C88.29 22.7422 88.3682 22.7357 88.4463 22.7227C88.5244 22.707 88.5843 22.6953 88.626 22.6875L88.8877 23.9258C88.8044 23.9518 88.6872 23.9818 88.5361 24.0156C88.3851 24.0521 88.2015 24.0742 87.9854 24.082C87.5843 24.0977 87.2327 24.0443 86.9307 23.9219C86.6312 23.7995 86.3981 23.6094 86.2314 23.3516C86.0648 23.0937 85.9827 22.7682 85.9854 22.375V16.5625ZM91.5732 24.1133C91.1904 24.1133 90.8493 24.0469 90.5498 23.9141C90.2503 23.7786 90.0133 23.5794 89.8389 23.3164C89.667 23.0508 89.5811 22.7201 89.5811 22.3242C89.5811 21.9909 89.6423 21.7109 89.7646 21.4844C89.887 21.2578 90.0537 21.0755 90.2646 20.9375C90.4756 20.7995 90.7152 20.6953 90.9834 20.625C91.2542 20.5547 91.5381 20.5052 91.835 20.4766C92.1839 20.4401 92.4652 20.4062 92.6787 20.375C92.8923 20.3411 93.0472 20.2917 93.1436 20.2266C93.2399 20.1615 93.2881 20.0651 93.2881 19.9375V19.9141C93.2881 19.6667 93.21 19.4753 93.0537 19.3398C92.9001 19.2044 92.6813 19.1367 92.3975 19.1367C92.098 19.1367 91.8597 19.2031 91.6826 19.3359C91.5055 19.4661 91.3883 19.6302 91.3311 19.8281L89.792 19.7031C89.8701 19.3385 90.0238 19.0234 90.2529 18.7578C90.4821 18.4896 90.7777 18.2839 91.1396 18.1406C91.5042 17.9948 91.9261 17.9219 92.4053 17.9219C92.7386 17.9219 93.0576 17.9609 93.3623 18.0391C93.6696 18.1172 93.9417 18.2383 94.1787 18.4023C94.4183 18.5664 94.6071 18.7773 94.7451 19.0352C94.8831 19.2904 94.9521 19.5964 94.9521 19.9531V24H93.374V23.168H93.3271C93.2308 23.3555 93.1019 23.5208 92.9404 23.6641C92.779 23.8047 92.585 23.9154 92.3584 23.9961C92.1318 24.0742 91.8701 24.1133 91.5732 24.1133ZM92.0498 22.9648C92.2946 22.9648 92.5107 22.9167 92.6982 22.8203C92.8857 22.7214 93.0329 22.5885 93.1396 22.4219C93.2464 22.2552 93.2998 22.0664 93.2998 21.8555V21.2188C93.2477 21.2526 93.1761 21.2839 93.085 21.3125C92.9964 21.3385 92.8962 21.3633 92.7842 21.3867C92.6722 21.4076 92.5602 21.4271 92.4482 21.4453C92.3363 21.4609 92.2347 21.4753 92.1436 21.4883C91.9482 21.5169 91.7777 21.5625 91.6318 21.625C91.486 21.6875 91.3727 21.7721 91.292 21.8789C91.2113 21.9831 91.1709 22.1133 91.1709 22.2695C91.1709 22.4961 91.2529 22.6693 91.417 22.7891C91.5837 22.9062 91.7946 22.9648 92.0498 22.9648ZM97.9072 16V24H96.2432V16H97.9072ZM101.975 24.1172C101.357 24.1172 100.826 23.9922 100.381 23.7422C99.9382 23.4896 99.597 23.1328 99.3574 22.6719C99.1178 22.2083 98.998 21.6602 98.998 21.0273C98.998 20.4102 99.1178 19.8685 99.3574 19.4023C99.597 18.9362 99.9342 18.5729 100.369 18.3125C100.807 18.0521 101.32 17.9219 101.908 17.9219C102.304 17.9219 102.673 17.9857 103.014 18.1133C103.357 18.2383 103.657 18.4271 103.912 18.6797C104.17 18.9323 104.37 19.25 104.514 19.6328C104.657 20.013 104.729 20.4583 104.729 20.9687V21.4258H99.6621V20.3945H103.162C103.162 20.1549 103.11 19.9427 103.006 19.7578C102.902 19.5729 102.757 19.4284 102.572 19.3242C102.39 19.2174 102.178 19.1641 101.936 19.1641C101.683 19.1641 101.459 19.2227 101.264 19.3398C101.071 19.4544 100.92 19.6094 100.811 19.8047C100.701 19.9974 100.645 20.2122 100.643 20.4492V21.4297C100.643 21.7266 100.697 21.9831 100.807 22.1992C100.919 22.4154 101.076 22.582 101.279 22.6992C101.482 22.8164 101.723 22.875 102.002 22.875C102.187 22.875 102.356 22.849 102.51 22.7969C102.663 22.7448 102.795 22.6667 102.904 22.5625C103.014 22.4583 103.097 22.3307 103.154 22.1797L104.693 22.2812C104.615 22.651 104.455 22.974 104.213 23.25C103.973 23.5234 103.663 23.737 103.283 23.8906C102.906 24.0417 102.469 24.1172 101.975 24.1172ZM110.071 24.1133C109.688 24.1133 109.347 24.0469 109.048 23.9141C108.748 23.7786 108.511 23.5794 108.337 23.3164C108.165 23.0508 108.079 22.7201 108.079 22.3242C108.079 21.9909 108.14 21.7109 108.263 21.4844C108.385 21.2578 108.552 21.0755 108.763 20.9375C108.974 20.7995 109.213 20.6953 109.481 20.625C109.752 20.5547 110.036 20.5052 110.333 20.4766C110.682 20.4401 110.963 20.4062 111.177 20.375C111.39 20.3411 111.545 20.2917 111.642 20.2266C111.738 20.1615 111.786 20.0651 111.786 19.9375V19.9141C111.786 19.6667 111.708 19.4753 111.552 19.3398C111.398 19.2044 111.179 19.1367 110.896 19.1367C110.596 19.1367 110.358 19.2031 110.181 19.3359C110.004 19.4661 109.886 19.6302 109.829 19.8281L108.29 19.7031C108.368 19.3385 108.522 19.0234 108.751 18.7578C108.98 18.4896 109.276 18.2839 109.638 18.1406C110.002 17.9948 110.424 17.9219 110.903 17.9219C111.237 17.9219 111.556 17.9609 111.86 18.0391C112.168 18.1172 112.44 18.2383 112.677 18.4023C112.916 18.5664 113.105 18.7773 113.243 19.0352C113.381 19.2904 113.45 19.5964 113.45 19.9531V24H111.872V23.168H111.825C111.729 23.3555 111.6 23.5208 111.438 23.6641C111.277 23.8047 111.083 23.9154 110.856 23.9961C110.63 24.0742 110.368 24.1133 110.071 24.1133ZM110.548 22.9648C110.793 22.9648 111.009 22.9167 111.196 22.8203C111.384 22.7214 111.531 22.5885 111.638 22.4219C111.744 22.2552 111.798 22.0664 111.798 21.8555V21.2188C111.746 21.2526 111.674 21.2839 111.583 21.3125C111.494 21.3385 111.394 21.3633 111.282 21.3867C111.17 21.4076 111.058 21.4271 110.946 21.4453C110.834 21.4609 110.733 21.4753 110.642 21.4883C110.446 21.5169 110.276 21.5625 110.13 21.625C109.984 21.6875 109.871 21.7721 109.79 21.8789C109.709 21.9831 109.669 22.1133 109.669 22.2695C109.669 22.4961 109.751 22.6693 109.915 22.7891C110.082 22.9062 110.293 22.9648 110.548 22.9648ZM117.318 24V16H119.01V19.5273H119.115L121.994 16H124.021L121.053 19.582L124.057 24H122.033L119.842 20.7109L119.01 21.7266V24H117.318ZM127.142 24.1172C126.535 24.1172 126.01 23.9883 125.567 23.7305C125.127 23.4701 124.787 23.1081 124.548 22.6445C124.308 22.1784 124.188 21.638 124.188 21.0234C124.188 20.4036 124.308 19.862 124.548 19.3984C124.787 18.9323 125.127 18.5703 125.567 18.3125C126.01 18.0521 126.535 17.9219 127.142 17.9219C127.748 17.9219 128.272 18.0521 128.712 18.3125C129.155 18.5703 129.496 18.9323 129.735 19.3984C129.975 19.862 130.095 20.4036 130.095 21.0234C130.095 21.638 129.975 22.1784 129.735 22.6445C129.496 23.1081 129.155 23.4701 128.712 23.7305C128.272 23.9883 127.748 24.1172 127.142 24.1172ZM127.149 22.8281C127.425 22.8281 127.656 22.75 127.841 22.5938C128.026 22.4349 128.165 22.2187 128.259 21.9453C128.355 21.6719 128.403 21.3607 128.403 21.0117C128.403 20.6628 128.355 20.3516 128.259 20.0781C128.165 19.8047 128.026 19.5885 127.841 19.4297C127.656 19.2708 127.425 19.1914 127.149 19.1914C126.871 19.1914 126.636 19.2708 126.446 19.4297C126.259 19.5885 126.117 19.8047 126.021 20.0781C125.927 20.3516 125.88 20.6628 125.88 21.0117C125.88 21.3607 125.927 21.6719 126.021 21.9453C126.117 22.2187 126.259 22.4349 126.446 22.5938C126.636 22.75 126.871 22.8281 127.149 22.8281ZM132.841 16V24H131.177V16H132.841ZM136.908 24.1172C136.291 24.1172 135.76 23.9922 135.314 23.7422C134.872 23.4896 134.531 23.1328 134.291 22.6719C134.051 22.2083 133.932 21.6602 133.932 21.0273C133.932 20.4102 134.051 19.8685 134.291 19.4023C134.531 18.9362 134.868 18.5729 135.303 18.3125C135.74 18.0521 136.253 17.9219 136.842 17.9219C137.238 17.9219 137.606 17.9857 137.947 18.1133C138.291 18.2383 138.59 18.4271 138.846 18.6797C139.104 18.9323 139.304 19.25 139.447 19.6328C139.59 20.013 139.662 20.4583 139.662 20.9687V21.4258H134.596V20.3945H138.096C138.096 20.1549 138.044 19.9427 137.939 19.7578C137.835 19.5729 137.691 19.4284 137.506 19.3242C137.324 19.2174 137.111 19.1641 136.869 19.1641C136.617 19.1641 136.393 19.2227 136.197 19.3398C136.005 19.4544 135.854 19.6094 135.744 19.8047C135.635 19.9974 135.579 20.2122 135.576 20.4492V21.4297C135.576 21.7266 135.631 21.9831 135.74 22.1992C135.852 22.4154 136.01 22.582 136.213 22.6992C136.416 22.8164 136.657 22.875 136.936 22.875C137.12 22.875 137.29 22.849 137.443 22.7969C137.597 22.7448 137.729 22.6667 137.838 22.5625C137.947 22.4583 138.031 22.3307 138.088 22.1797L139.627 22.2812C139.549 22.651 139.389 22.974 139.146 23.25C138.907 23.5234 138.597 23.737 138.217 23.8906C137.839 24.0417 137.403 24.1172 136.908 24.1172ZM142.031 18L143.133 20.0977L144.262 18H145.969L144.23 21L146.016 24H144.316L143.133 21.9258L141.969 24H140.25L142.031 21L140.313 18H142.031ZM148.636 24.1133C148.253 24.1133 147.912 24.0469 147.612 23.9141C147.313 23.7786 147.076 23.5794 146.901 23.3164C146.729 23.0508 146.644 22.7201 146.644 22.3242C146.644 21.9909 146.705 21.7109 146.827 21.4844C146.95 21.2578 147.116 21.0755 147.327 20.9375C147.538 20.7995 147.778 20.6953 148.046 20.625C148.317 20.5547 148.601 20.5052 148.897 20.4766C149.246 20.4401 149.528 20.4062 149.741 20.375C149.955 20.3411 150.11 20.2917 150.206 20.2266C150.302 20.1615 150.351 20.0651 150.351 19.9375V19.9141C150.351 19.6667 150.272 19.4753 150.116 19.3398C149.963 19.2044 149.744 19.1367 149.46 19.1367C149.16 19.1367 148.922 19.2031 148.745 19.3359C148.568 19.4661 148.451 19.6302 148.394 19.8281L146.854 19.7031C146.933 19.3385 147.086 19.0234 147.315 18.7578C147.545 18.4896 147.84 18.2839 148.202 18.1406C148.567 17.9948 148.989 17.9219 149.468 17.9219C149.801 17.9219 150.12 17.9609 150.425 18.0391C150.732 18.1172 151.004 18.2383 151.241 18.4023C151.481 18.5664 151.67 18.7773 151.808 19.0352C151.946 19.2904 152.015 19.5964 152.015 19.9531V24H150.437V23.168H150.39C150.293 23.3555 150.164 23.5208 150.003 23.6641C149.841 23.8047 149.647 23.9154 149.421 23.9961C149.194 24.0742 148.933 24.1133 148.636 24.1133ZM149.112 22.9648C149.357 22.9648 149.573 22.9167 149.761 22.8203C149.948 22.7214 150.095 22.5885 150.202 22.4219C150.309 22.2552 150.362 22.0664 150.362 21.8555V21.2188C150.31 21.2526 150.239 21.2839 150.147 21.3125C150.059 21.3385 149.959 21.3633 149.847 21.3867C149.735 21.4076 149.623 21.4271 149.511 21.4453C149.399 21.4609 149.297 21.4753 149.206 21.4883C149.011 21.5169 148.84 21.5625 148.694 21.625C148.549 21.6875 148.435 21.7721 148.354 21.8789C148.274 21.9831 148.233 22.1133 148.233 22.2695C148.233 22.4961 148.315 22.6693 148.479 22.7891C148.646 22.9062 148.857 22.9648 149.112 22.9648Z" fill="#FFF1FF"/>'
    '<path d="M22.5811 9C23.4542 9 24.1621 9.70791 24.1621 10.5811V14.1641L24.9648 14.7695L29.5664 11.2988C30.158 10.8529 31.0777 10.9006 31.6201 11.4053C32.1623 11.9099 32.1225 12.6808 31.5312 13.127L27.1582 16.4248L29.5664 18.2412C30.1578 18.6874 30.1975 19.4582 29.6553 19.9629C29.1128 20.4676 28.1932 20.5154 27.6016 20.0693L24.7148 17.8916C24.5281 17.8973 24.3403 17.8733 24.1621 17.8193V21.4189C24.1621 22.2921 23.4542 23 22.5811 23C21.708 22.9999 21 22.292 21 21.4189V10.5811C21 9.70796 21.708 9.00008 22.5811 9Z" fill="#FFF1FF"/>'
    '<path d="M38.2762 25.861C38.277 26.0016 38.2343 26.139 38.1539 26.2543C38.0735 26.3696 37.9593 26.4571 37.8271 26.5049L35.6042 27.3263L34.7854 29.5509C34.7369 29.6826 34.6492 29.7963 34.534 29.8766C34.4189 29.9569 34.2819 30 34.1415 30C34.0012 30 33.8642 29.9569 33.749 29.8766C33.6339 29.7963 33.5462 29.6826 33.4977 29.5509L32.6737 27.3263L30.4491 26.5075C30.3174 26.459 30.2037 26.3713 30.1234 26.2561C30.0431 26.141 30 26.004 30 25.8636C30 25.7233 30.0431 25.5863 30.1234 25.4711C30.2037 25.356 30.3174 25.2683 30.4491 25.2198L32.6737 24.3958L33.4925 22.1712C33.541 22.0394 33.6287 21.9258 33.7439 21.8454C33.859 21.7651 33.996 21.7221 34.1364 21.7221C34.2767 21.7221 34.4137 21.7651 34.5289 21.8454C34.644 21.9258 34.7317 22.0394 34.7802 22.1712L35.6042 24.3958L37.8288 25.2146C37.9611 25.2628 38.0752 25.3508 38.1554 25.4666C38.2355 25.5824 38.2777 25.7202 38.2762 25.861ZM35.8628 21.7238H36.5523V22.4134C36.5523 22.5048 36.5887 22.5925 36.6533 22.6572C36.718 22.7218 36.8057 22.7581 36.8971 22.7581C36.9885 22.7581 37.0762 22.7218 37.1409 22.6572C37.2055 22.5925 37.2419 22.5048 37.2419 22.4134V21.7238H37.9314C38.0228 21.7238 38.1105 21.6875 38.1752 21.6229C38.2398 21.5582 38.2762 21.4705 38.2762 21.3791C38.2762 21.2876 38.2398 21.1999 38.1752 21.1353C38.1105 21.0706 38.0228 21.0343 37.9314 21.0343H37.2419V20.3448C37.2419 20.2533 37.2055 20.1656 37.1409 20.101C37.0762 20.0363 36.9885 20 36.8971 20C36.8057 20 36.718 20.0363 36.6533 20.101C36.5887 20.1656 36.5523 20.2533 36.5523 20.3448V21.0343H35.8628C35.7714 21.0343 35.6837 21.0706 35.619 21.1353C35.5544 21.1999 35.518 21.2876 35.518 21.3791C35.518 21.4705 35.5544 21.5582 35.619 21.6229C35.6837 21.6875 35.7714 21.7238 35.8628 21.7238ZM39.6552 23.1029H39.3105V22.7581C39.3105 22.6667 39.2741 22.579 39.2095 22.5144C39.1448 22.4497 39.0571 22.4134 38.9657 22.4134C38.8743 22.4134 38.7866 22.4497 38.7219 22.5144C38.6573 22.579 38.6209 22.6667 38.6209 22.7581V23.1029H38.2762C38.1847 23.1029 38.097 23.1392 38.0324 23.2039C37.9677 23.2685 37.9314 23.3562 37.9314 23.4477C37.9314 23.5391 37.9677 23.6268 38.0324 23.6915C38.097 23.7561 38.1847 23.7924 38.2762 23.7924H38.6209V24.1372C38.6209 24.2286 38.6573 24.3163 38.7219 24.381C38.7866 24.4456 38.8743 24.482 38.9657 24.482C39.0571 24.482 39.1448 24.4456 39.2095 24.381C39.2741 24.3163 39.3105 24.2286 39.3105 24.1372V23.7924H39.6552C39.7467 23.7924 39.8344 23.7561 39.899 23.6915C39.9637 23.6268 40 23.5391 40 23.4477C40 23.3562 39.9637 23.2685 39.899 23.2039C39.8344 23.1392 39.7467 23.1029 39.6552 23.1029Z" fill="#FFF1FF"/>'
    '</svg>';

class InboxPage extends StatefulWidget {
  // Solo lo usa el padre (búsqueda "sobre {hijo}" + avatar) — docente/
  // director no tienen un solo alumno seleccionado, así que quedan null
  // para ellos y el buscador muestra un texto genérico sin avatar.
  final String? studentName;
  final String? studentAvatarUrl;
  final String? studentInitials;

  const InboxPage({
    super.key,
    this.studentName,
    this.studentAvatarUrl,
    this.studentInitials,
  });

  @override
  State<InboxPage> createState() => _InboxPageState();
}

// Chips de filtro del diseño: solo "Mensajes" tiene datos reales detrás
// (todos los hilos son kind:'direct' en el backend hoy). Los otros dos
// existen visualmente pero no ocultan/muestran nada real.
enum _InboxFilter { mensajes, comunicados, reuniones }

class _InboxPageState extends State<InboxPage> with WidgetsBindingObserver {
  // Cache en memoria a nivel de clase: sobrevive a que esta pantalla se
  // destruya y se vuelva a crear (ej. al cambiar de pestaña y volver), así
  // que reabrir Chats muestra la última lista conocida al instante, sin
  // loader — se refresca sola en segundo plano.
  static List<ThreadSummary>? _cachedThreads;

  List<ThreadSummary>? _threads;
  bool _loadingFirstTime = false;
  String? _error;
  _InboxFilter _filter = _InboxFilter.mensajes;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _threads = _cachedThreads;
    _refresh(showErrorIfEmpty: true);
    PushNotificationsService.instance.addDataRefreshListener(_handleDataRefresh);
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  // Red de seguridad si el push no llegó mientras la app estaba en
  // background (conocido en gama baja/media, mismo patrón que
  // ThreadPage): al volver a primer plano, se refresca igual. De paso
  // "precalienta" la conexión (TCP/TLS) antes de que el usuario llegue a
  // mirar la bandeja, en vez de pagar ese costo recién cuando la abre.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotificationsService.instance.removeDataRefreshListener(_handleDataRefresh);
    _searchController.dispose();
    super.dispose();
  }

  // Llega un mensaje nuevo en cualquier conversación: la bandeja se
  // refresca sola (nuevo orden, preview, punto de no-leído) sin que haga
  // falta salir y volver a entrar a la pestaña.
  void _handleDataRefresh(Map<String, dynamic> data) {
    if (!mounted || data['screen'] != 'thread') return;
    _refresh();
  }

  // Refresco silencioso: nunca borra `_threads` antes de tener el
  // resultado nuevo, así la lista ya cargada se queda visible en pantalla
  // mientras se pide de nuevo (a diferencia de un FutureBuilder, que
  // vuelve a mostrar el loader cada vez que se reemplaza el Future). El
  // spinner de pantalla completa solo aparece si de verdad no hay nada
  // que mostrar todavía.
  Future<void> _refresh({bool showErrorIfEmpty = false}) async {
    if (_threads == null) setState(() => _loadingFirstTime = true);
    try {
      final repo = ThreadsRepository(context.read<ApiClient>());
      final threads = await repo.getInbox();
      _cachedThreads = threads;
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _error = null;
        _loadingFirstTime = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFirstTime = false);
      // Un refresh silencioso que falla no debe tapar la lista ya cargada
      // con una pantalla de error — solo se muestra si no hay nada.
      if (showErrorIfEmpty && _threads == null) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _onRefresh() => _refresh(showErrorIfEmpty: true);

  Future<void> _openNewMessage() async {
    final opened = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewMessagePage()),
    );
    if (opened == true) await _onRefresh();
  }

  Future<void> _openThread(ThreadSummary t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadPage(
          threadId: t.id,
          title: t.otherParticipant?.name ?? 'Conversación',
          avatarUrl: t.otherParticipant?.avatar,
          online: t.otherParticipant?.online ?? false,
          studentId: t.studentId,
          studentName: t.studentName,
        ),
      ),
    );
    await _onRefresh();
  }

  void _selectFilter(_InboxFilter f) {
    setState(() => _filter = f);
    if (f != _InboxFilter.mensajes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no disponible')),
      );
    }
  }

  List<ThreadSummary> _applySearch(List<ThreadSummary> threads) {
    if (_searchQuery.isEmpty) return threads;
    return threads.where((t) {
      final name = (t.otherParticipant?.name ?? '').toLowerCase();
      final preview = (t.lastMessage?.body ?? '').toLowerCase();
      final student = (t.studentName ?? '').toLowerCase();
      return name.contains(_searchQuery) ||
          preview.contains(_searchQuery) ||
          student.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final threads = _threads ?? [];
    final unreadCount = threads.where((t) => t.unread).length;

    return Container(
      color: _kBg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 20, 15, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Mensajes',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold, color: _kHeaderTitle)),
                    ),
                    GestureDetector(
                      onTap: _openNewMessage,
                      child: Container(
                        width: 33,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _kAccentLt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.string(_kSvgComposeNewMessage, width: 14, height: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: _SearchBar(
                  controller: _searchController,
                  studentName: widget.studentName,
                  studentAvatarUrl: widget.studentAvatarUrl,
                  studentInitials: widget.studentInitials,
                ),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Mensajes',
                      width: 92,
                      count: unreadCount,
                      active: _filter == _InboxFilter.mensajes,
                      onTap: () => _selectFilter(_InboxFilter.mensajes),
                    ),
                    const SizedBox(width: 5),
                    _FilterChip(
                      label: 'Comunicados',
                      width: 112,
                      active: _filter == _InboxFilter.comunicados,
                      onTap: () => _selectFilter(_InboxFilter.comunicados),
                    ),
                    const SizedBox(width: 5),
                    _FilterChip(
                      label: 'Reuniones',
                      width: 90,
                      active: _filter == _InboxFilter.reuniones,
                      onTap: () => _selectFilter(_InboxFilter.reuniones),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RefreshIndicator(
                  color: _kAccent,
                  onRefresh: _onRefresh,
                  child: Builder(builder: (context) {
                    if (_filter != _InboxFilter.mensajes) {
                      return const _UnavailableState();
                    }
                    if (_threads == null) {
                      if (_loadingFirstTime) {
                        return const Center(child: CircularProgressIndicator(color: _kAccent));
                      }
                      if (_error != null) {
                        return _ErrorState(onRetry: _onRefresh);
                      }
                    }
                    if (threads.isEmpty) {
                      return _EmptyState(onNewMessage: _openNewMessage);
                    }
                    final visible = _applySearch(threads);
                    if (visible.isEmpty) {
                      return const _NoResultsState();
                    }
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visible.length,
                      itemBuilder: (context, i) => _ThreadRow(
                        thread: visible[i],
                        onTap: () => _openThread(visible[i]),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          // Botón flotante del asistente — todavía no hay pantalla/endpoint
          // de IA detrás, así que por ahora solo avisa que está en camino.
          Positioned(
            bottom: 44,
            right: 23,
            child: GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Muy pronto podrás preguntarle a Kolexa')),
              ),
              child: SvgPicture.string(_kSvgKolexaButton, width: 181, height: 40),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String? studentName;
  final String? studentAvatarUrl;
  final String? studentInitials;
  const _SearchBar({
    required this.controller,
    this.studentName,
    this.studentAvatarUrl,
    this.studentInitials,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = studentName?.trim().split(' ').first;
    final hint = firstName != null && firstName.isNotEmpty
        ? 'Busca cualquier mensaje sobre $firstName...'
        : 'Busca cualquier mensaje...';
    return Container(
      height: 37,
      padding: const EdgeInsets.fromLTRB(9, 0, 11, 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          SvgPicture.string(_kSvgMagnifyingGlass, width: 17, height: 17),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              controller: controller,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 11, color: _kTextGray, fontWeight: FontWeight.w300),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 11, color: _kTextGray, fontWeight: FontWeight.w300),
              ),
            ),
          ),
          if (studentName != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: _kBg, width: 1)),
              ),
              child: CircleAvatar(
                radius: 11,
                backgroundColor: _kPrimaryLt,
                backgroundImage: studentAvatarUrl != null ? NetworkImage(studentAvatarUrl!) : null,
                child: studentAvatarUrl == null
                    ? Text(studentInitials ?? '?',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kPrimary))
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final double width;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.width,
    this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? _kPrimary : _kTextGray;
    final badgeBg = active ? _kChipBadgeActiveBg : _kChipBadgeInactiveBg;
    final badgeFg = active ? _kPrimary : _kChipBadgeInactiveText;
    final hasBadge = count != null && count! > 0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg)),
        if (hasBadge) ...[
          const SizedBox(width: 4),
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$count',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: badgeFg)),
          ),
        ],
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 30,
        padding: hasBadge ? const EdgeInsets.only(left: 12) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: active ? _kPrimaryLt : _kChipInactiveBg,
          borderRadius: BorderRadius.circular(10),
        ),
        // Con badge: contenido pegado a la izquierda con margen fijo (así
        // está en Figma). Sin badge: el texto se centra en el chip — no
        // hay nada más que lo "empuje" a un lado.
        alignment: hasBadge ? Alignment.centerLeft : Alignment.center,
        child: content,
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final ThreadSummary thread;
  final VoidCallback onTap;
  const _ThreadRow({required this.thread, required this.onTap});

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isEmpty) return '?';
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final period = dt.hour < 12 ? 'a. m.' : 'p. m.';
      return '$h:${dt.minute.toString().padLeft(2, '0')} $period';
    }
    const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    final diff = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff < 7) return days[dt.weekday - 1];
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final name = thread.otherParticipant?.name ?? 'Colegio';
    final unread = thread.unread;
    final myUserId = context.read<AuthBloc>().state is AuthAuthenticated
        ? (context.read<AuthBloc>().state as AuthAuthenticated).user.id.toString()
        : null;
    final sentByMe = thread.lastMessage != null && thread.lastMessage!.senderId == myUserId;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 11, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: _kBg, width: 1)),
                      ),
                      child: CircleAvatar(
                        radius: 17.5,
                        backgroundColor: _kAccentLt,
                        backgroundImage: thread.otherParticipant?.avatar != null
                            ? NetworkImage(thread.otherParticipant!.avatar!)
                            : null,
                        child: thread.otherParticipant?.avatar == null
                            ? Text(_initials(name),
                                style: const TextStyle(
                                    color: _kAccent, fontWeight: FontWeight.w700, fontSize: 13))
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 3,
                      bottom: 6,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: (thread.otherParticipant?.online ?? false) ? _kOnlineDot : _kOfflineDot,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: _kBg, width: 1)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: unread ? _kUnreadText : _kTextGray)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (sentByMe) ...[
                            (thread.lastMessage?.delivered ?? false)
                                ? SvgPicture.string(_kSvgDoubleCheck, width: 14, height: 6)
                                : SvgPicture.string(_kSvgSingleCheck, width: 10, height: 6),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              thread.lastMessage?.body ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: unread ? _kUnreadText : _kTextGray,
                                fontWeight: unread ? FontWeight.w400 : FontWeight.w300,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_timeLabel(thread.lastMessageAt),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: unread ? FontWeight.w500 : FontWeight.w300,
                          color: unread ? _kAccent : _kTextGray,
                        )),
                    if (unread) ...[
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            thread.unreadCount > 9 ? '9+' : '${thread.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Aún no disponible', style: TextStyle(color: _kTextGray)),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Sin resultados', style: TextStyle(color: _kTextGray)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewMessage;
  const _EmptyState({required this.onNewMessage});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 40, color: _kTextGray),
                  const SizedBox(height: 12),
                  const Text('Sin conversaciones todavía',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _kUnreadText)),
                  const SizedBox(height: 6),
                  const Text(
                    'Escríbele al docente o al colegio cuando lo necesites.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _kTextGray),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: onNewMessage,
                    icon: const Icon(Icons.add, color: _kAccent),
                    label: const Text('Nuevo mensaje', style: TextStyle(color: _kAccent)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron cargar tus chats',
                    style: TextStyle(color: _kUnreadText, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
